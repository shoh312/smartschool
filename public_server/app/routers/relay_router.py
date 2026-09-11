# -*- coding: utf-8 -*-
"""Reaching a school server from outside its LAN.

The school server sits behind a home router with no inbound route. Instead
of asking every school to open a port, the school server opens *one*
outbound websocket to here and keeps it open (see the school server's
``app/relay_client.py``). Anything a director's or teacher's phone sends to
``/relay/...`` is wrapped up, pushed down that socket, answered by the
school server against its own API, and unwrapped here.

Websockets (the live camera stream, the live attendance feed) travel the
same way: a client socket on ``/relay/ws/...`` becomes a matching socket on
the school side, and frames are pumped through in both directions.

Wire format on the tunnel
-------------------------
Text frames are JSON control messages::

    {"type": "hello", "school_key": "..."}                 school -> here, once
    {"type": "http", "id", "method", "path", "query",
     "headers", "body_b64"}                                 here -> school
    {"type": "http_response", "id", "status", "headers",
     "body_b64"}                                            school -> here
    {"type": "ws_open", "id", "path", "query"}              here -> school
    {"type": "ws_opened", "id"} / {"type": "ws_close", "id"}   either way

Binary frames carry websocket data: 36 bytes of the stream id, one byte
``b``/``t`` for the frame kind, then the payload. Kept binary so a JPEG
frame is not base64-inflated forty times a second.

Security: the tunnel is authenticated with the same per-school key the sync
uses. Everything forwarded is then subject to the school server's own
login -- the relay adds no access, only a route.
"""

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

HTTP_TIMEOUT = 400  # drafting a material through Gemini can take minutes
HOP_HEADERS = {"host", "connection", "content-length", "transfer-encoding", "keep-alive", "upgrade"}


class Tunnel:
    """One connected school server."""

    def __init__(self, school_id: int, name: str, ws: WebSocket):
        self.school_id = school_id
        self.name = name
        self.ws = ws
        self.pending: dict[str, asyncio.Future] = {}
        # stream id -> queue of frames coming back from the school side
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
    for school in db.query(School).filter(School.is_active == True).all():  # noqa: E712
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


# --------------------------------------------------------------------------
# The school server's side of the tunnel
# --------------------------------------------------------------------------

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
        # A reconnect after a dropped link: the stale socket is replaced,
        # never left to shadow the live one.
        try:
            await old.ws.close(code=1012, reason="replaced")
        except Exception:
            pass

    tunnel = Tunnel(school.id, school.name, websocket)
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
    except Exception as exc:  # noqa: BLE001 -- the tunnel must not take the server down
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
    """Which schools are reachable right now -- for a director wondering why."""
    return [{"school_id": t.school_id, "name": t.name} for t in tunnels.values()]


# --------------------------------------------------------------------------
# What the phones call
# --------------------------------------------------------------------------

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
    stream_id = str(uuid.uuid4())
    queue: asyncio.Queue = asyncio.Queue()
    tunnel.streams[stream_id] = queue
    query = "&".join(part for part in websocket.url.query.split("&") if part and not part.startswith("school="))

    try:
        await tunnel.send_json({"type": "ws_open", "id": stream_id, "path": "/" + path, "query": query})
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

        async def school_to_client():
            while True:
                item = await queue.get()
                if isinstance(item, dict):
                    return  # ws_close / ws_error
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
    except Exception as exc:  # noqa: BLE001
        logger.debug("relay: stream %s ended: %s", stream_id, exc)
    finally:
        tunnel.streams.pop(stream_id, None)
        try:
            await tunnel.send_json({"type": "ws_close", "id": stream_id})
        except Exception:
            pass
        try:
            await websocket.close()
        except Exception:
            pass
