
import asyncio
import base64
import json
import logging
import uuid

from fastapi import APIRouter, Header, HTTPException, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models.school_model import School
from app.utils.security import verify_school_key

logger = logging.getLogger(__name__)

router = APIRouter(tags=["relay"])

HTTP_TIMEOUT = 400
HOP_HEADERS = {"host", "connection", "content-length", "transfer-encoding", "keep-alive", "upgrade"}


class Tunnel:

    def __init__(self, school_id: int, name: str, ws: WebSocket, relay_secret: str | None = None):
        self.school_id = school_id
        self.name = name
        self.ws = ws
        self.relay_secret = relay_secret
        self.pending: dict[str, asyncio.Future] = {}
        self.streams: dict[str, asyncio.Queue] = {}
        self.send_lock = asyncio.Lock()

    async def send_json(self, payload: dict) -> None:
        async with self.send_lock:
            await self.ws.send_text(json.dumps(payload))

    async def send_frame(self, stream_id: str, kind: bytes, data: bytes) -> None:
        async with self.send_lock:
            await self.ws.send_bytes(stream_id.encode("ascii") + kind + data)


tunnels: dict[int, Tunnel] = {}


def _authenticate(db: Session, key: str | None) -> School | None:
    if not key:
        return None
    for school in db.query(School).filter(School.is_active == True).all():
        if verify_school_key(key, school.api_key_hash):
            return school
    return None


def _pick(school_id: int | None) -> Tunnel:
    if school_id is not None:
        tunnel = tunnels.get(school_id)
        if tunnel is None:
            raise HTTPException(status_code=503, detail="school_offline")
        return tunnel
    if not tunnels:
        raise HTTPException(status_code=503, detail="school_offline")
    if len(tunnels) > 1:
        raise HTTPException(status_code=400, detail="school_ambiguous")
    return next(iter(tunnels.values()))


@router.websocket("/relay/tunnel")
async def tunnel_socket(websocket: WebSocket):
    await websocket.accept()
    try:
        hello = json.loads(await asyncio.wait_for(websocket.receive_text(), timeout=10))
    except Exception:
        await websocket.close(code=1008, reason="hello_expected")
        return

    db = SessionLocal()
    try:
        school = _authenticate(db, hello.get("school_key")) if hello.get("type") == "hello" else None
    finally:
        db.close()
    if school is None:
        await websocket.close(code=1008, reason="invalid_school_key")
        return

    old = tunnels.get(school.id)
    if old is not None:
        try:
            await old.ws.close(code=1012, reason="replaced")
        except Exception:
            pass

    tunnel = Tunnel(school.id, school.name, websocket, hello.get("relay_secret"))
    tunnels[school.id] = tunnel
    logger.info("relay: school %s (%s) connected", school.id, school.name)
    await tunnel.send_json({"type": "welcome", "school_id": school.id})

    try:
        while True:
            message = await websocket.receive()
            if message.get("type") == "websocket.disconnect":
                break
            if message.get("bytes") is not None:
                raw = message["bytes"]
                stream_id = raw[:36].decode("ascii", "replace")
                queue = tunnel.streams.get(stream_id)
                if queue is not None:
                    queue.put_nowait(raw[36:])
                continue
            text = message.get("text")
            if not text:
                continue
            payload = json.loads(text)
            kind = payload.get("type")
            if kind == "http_response":
                future = tunnel.pending.pop(payload.get("id"), None)
                if future is not None and not future.done():
                    future.set_result(payload)
            elif kind in ("ws_opened", "ws_close", "ws_error"):
                queue = tunnel.streams.get(payload.get("id"))
                if queue is not None:
                    queue.put_nowait(payload)
    except WebSocketDisconnect:
        pass
    except Exception as exc:
        logger.warning("relay: tunnel for school %s ended: %s", school.id, exc)
    finally:
        if tunnels.get(school.id) is tunnel:
            del tunnels[school.id]
        for future in tunnel.pending.values():
            if not future.done():
                future.set_exception(HTTPException(status_code=503, detail="school_offline"))
        for queue in tunnel.streams.values():
            queue.put_nowait({"type": "ws_close"})
        logger.info("relay: school %s disconnected", school.id)


@router.get("/relay-status")
def relay_status():
    return [{"school_id": t.school_id, "name": t.name} for t in tunnels.values()]


@router.api_route("/relay/{path:path}", methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"])
async def relay_http(path: str, request: Request, x_school_id: int | None = Header(default=None)):
    tunnel = _pick(x_school_id)
    body = await request.body()
    headers = {k: v for k, v in request.headers.items() if k.lower() not in HOP_HEADERS and k.lower() != "x-school-id"}
    request_id = str(uuid.uuid4())
    loop = asyncio.get_running_loop()
    future: asyncio.Future = loop.create_future()
    tunnel.pending[request_id] = future
    try:
        await tunnel.send_json({
            "type": "http",
            "id": request_id,
            "method": request.method,
            "path": "/" + path,
            "query": request.url.query,
            "headers": headers,
            "body_b64": base64.b64encode(body).decode("ascii") if body else "",
        })
        reply = await asyncio.wait_for(future, timeout=HTTP_TIMEOUT)
    except asyncio.TimeoutError:
        tunnel.pending.pop(request_id, None)
        raise HTTPException(status_code=504, detail="school_timeout")
    except Exception:
        tunnel.pending.pop(request_id, None)
        raise

    content = base64.b64decode(reply.get("body_b64") or "")
    reply_headers = {k: v for k, v in (reply.get("headers") or {}).items() if k.lower() not in HOP_HEADERS}
    return Response(content=content, status_code=int(reply.get("status", 502)), headers=reply_headers)


async def _pump(websocket: WebSocket, tunnel: Tunnel, path: str, query: str) -> None:
    stream_id = str(uuid.uuid4())
    queue: asyncio.Queue = asyncio.Queue()
    tunnel.streams[stream_id] = queue
    try:
        await tunnel.send_json({"type": "ws_open", "id": stream_id, "path": path, "query": query})
        opened = await asyncio.wait_for(queue.get(), timeout=15)
        if not isinstance(opened, dict) or opened.get("type") != "ws_opened":
            await websocket.close(code=1011, reason="school_refused")
            return

        async def client_to_school():
            while True:
                message = await websocket.receive()
                if message.get("type") == "websocket.disconnect":
                    return
                if message.get("bytes") is not None:
                    await tunnel.send_frame(stream_id, b"b", message["bytes"])
                elif message.get("text") is not None:
                    await tunnel.send_frame(stream_id, b"t", message["text"].encode("utf-8"))

        close_reason: list[str | None] = [None]

        async def school_to_client():
            while True:
                item = await queue.get()
                if isinstance(item, dict):
                    close_reason[0] = item.get("reason")
                    return
                kind, data = item[:1], item[1:]
                if kind == b"t":
                    await websocket.send_text(data.decode("utf-8", "replace"))
                else:
                    await websocket.send_bytes(data)

        done, pending = await asyncio.wait(
            [asyncio.create_task(client_to_school()), asyncio.create_task(school_to_client())],
            return_when=asyncio.FIRST_COMPLETED,
        )
        for task in pending:
            task.cancel()
    except (WebSocketDisconnect, asyncio.TimeoutError):
        pass
    except Exception as exc:
        logger.debug("relay: stream %s ended: %s", stream_id, exc)
    finally:
        tunnel.streams.pop(stream_id, None)
        try:
            await tunnel.send_json({"type": "ws_close", "id": stream_id})
        except Exception:
            pass
        try:
            reason = close_reason[0] if "close_reason" in locals() else None
            if reason:
                await websocket.close(code=1008, reason=str(reason))
            else:
                await websocket.close()
        except Exception:
            pass


@router.websocket("/relay/{path:path}")
async def relay_websocket(websocket: WebSocket, path: str):
    school_id = websocket.query_params.get("school")
    try:
        tunnel = _pick(int(school_id) if school_id else None)
    except HTTPException as exc:
        await websocket.accept()
        await websocket.close(code=1013, reason=str(exc.detail))
        return

    await websocket.accept()
    query = "&".join(part for part in websocket.url.query.split("&") if part and not part.startswith("school="))
    await _pump(websocket, tunnel, "/" + path, query)


@router.websocket("/parent/live")
async def parent_live(websocket: WebSocket):
    from app.models.parent_model import Parent
    from app.models.student_model import Student
    from app.utils.security import verify_parent_access_token

    await websocket.accept()
    token = websocket.query_params.get("token") or ""
    try:
        student_id = int(websocket.query_params.get("student_id") or 0)
    except ValueError:
        student_id = 0
    db = SessionLocal()
    try:
        try:
            parent_id = verify_parent_access_token(token)
        except HTTPException:
            await websocket.close(code=1008, reason="forbidden")
            return
        parent = db.query(Parent).filter(Parent.id == parent_id).first()
        student = db.query(Student).filter(Student.id == student_id).first()
        if parent is None or student is None:
            await websocket.close(code=1008, reason="forbidden")
            return
        family = {p.id for p in db.query(Parent).filter(Parent.phone == parent.phone).all()}
        if student.parent_id not in family:
            await websocket.close(code=1008, reason="forbidden")
            return
        school_id, class_id = student.school_id, student.local_class_id
    finally:
        db.close()

    tunnel = tunnels.get(school_id)
    if tunnel is None or not tunnel.relay_secret:
        await websocket.close(code=1013, reason="school_offline")
        return
    if not class_id:
        await websocket.close(code=1008, reason="no_lesson")
        return
    await _pump(websocket, tunnel, "/ws/parent-stream", f"class_id={class_id}&secret={tunnel.relay_secret}")
