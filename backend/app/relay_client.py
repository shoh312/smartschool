# -*- coding: utf-8 -*-
"""The school server's end of the relay (see the Public Server's
``routers/relay_router.py`` for the wire format).

This server has no address on the internet. What it has is an outbound
route to the Public Server, so it dials out, keeps that socket open, and
answers whatever comes back down it against its own API -- in-process for
HTTP, and over a loopback websocket for the streams. A director on mobile
data ends up talking to this box exactly as they would on the school Wi-Fi,
only slower.

The connection is kept alive for the life of the process and re-dialled
with a backoff whenever it drops: the public server restarting, the
school's internet flapping, the router rebooting at night. None of that
needs a person.
"""

import asyncio
import base64
import json
import logging
import random

import httpx
import websockets

from app.utils.config import settings

logger = logging.getLogger(__name__)

RECONNECT_MIN = 3
RECONNECT_MAX = 60


def _tunnel_url() -> str:
    base = settings.public_server_url.rstrip("/")
    if base.startswith("https://"):
        base = "wss://" + base[len("https://"):]
    elif base.startswith("http://"):
        base = "ws://" + base[len("http://"):]
    return base + "/relay/tunnel"


async def relay_loop() -> None:
    """Runs forever. Started from main.py alongside the other background loops."""
    if not settings.public_server_api_key:
        logger.warning("relay: PUBLIC_SERVER_API_KEY is empty; the school will not be reachable from outside")
        return
    delay = RECONNECT_MIN
    while True:
        try:
            await _serve_once()
            delay = RECONNECT_MIN
        except Exception as exc:  # noqa: BLE001 -- keep dialling whatever went wrong
            logger.warning("relay: link down (%s); retrying in %ss", type(exc).__name__, delay)
        await asyncio.sleep(delay + random.uniform(0, 2))
        delay = min(delay * 2, RECONNECT_MAX)


async def _serve_once() -> None:
    # Imported here, not at module top: main.py imports this module, and the
    # app object does not exist until main.py has finished.
    from app.main import app

    url = _tunnel_url()
    async with websockets.connect(url, max_size=16 * 1024 * 1024, ping_interval=20, ping_timeout=20) as ws:
        await ws.send(json.dumps({"type": "hello", "school_key": settings.public_server_api_key}))
        welcome = json.loads(await asyncio.wait_for(ws.recv(), timeout=15))
        if welcome.get("type") != "welcome":
            raise RuntimeError("relay: unexpected welcome %r" % (welcome,))
        logger.info("relay: connected to %s as school %s", url, welcome.get("school_id"))

        send_lock = asyncio.Lock()
        streams: dict[str, "_Stream"] = {}

        async def send_json(payload: dict) -> None:
            async with send_lock:
                await ws.send(json.dumps(payload))

        async def send_frame(stream_id: str, kind: bytes, data: bytes) -> None:
            async with send_lock:
                await ws.send(stream_id.encode("ascii") + kind + data)

        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://relay.local", timeout=110) as client:
            async for raw in ws:
                if isinstance(raw, (bytes, bytearray)):
                    stream = streams.get(raw[:36].decode("ascii", "replace"))
                    if stream is not None:
                        await stream.to_local(raw[36:37], raw[37:])
                    continue
                payload = json.loads(raw)
                kind = payload.get("type")
                if kind == "http":
                    asyncio.create_task(_answer_http(client, payload, send_json))
                elif kind == "ws_open":
                    stream = _Stream(payload["id"], payload.get("path", "/"), payload.get("query", ""), send_json, send_frame)
                    streams[stream.id] = stream
                    asyncio.create_task(stream.run(lambda: streams.pop(stream.id, None)))
                elif kind == "ws_close":
                    stream = streams.pop(payload.get("id"), None)
                    if stream is not None:
                        await stream.close()


async def _answer_http(client: httpx.AsyncClient, payload: dict, send_json) -> None:
    request_id = payload.get("id")
    try:
        path = payload.get("path", "/")
        query = payload.get("query") or ""
        headers = {k: v for k, v in (payload.get("headers") or {}).items()}
        body = base64.b64decode(payload.get("body_b64") or "")
        response = await client.request(
            payload.get("method", "GET"),
            path + ("?" + query if query else ""),
            headers=headers,
            content=body,
        )
        await send_json({
            "type": "http_response",
            "id": request_id,
            "status": response.status_code,
            "headers": {k: v for k, v in response.headers.items() if k.lower() in ("content-type", "content-disposition", "cache-control")},
            "body_b64": base64.b64encode(response.content).decode("ascii"),
        })
    except Exception as exc:  # noqa: BLE001
        logger.warning("relay: request %s failed: %s", request_id, exc)
        await send_json({
            "type": "http_response", "id": request_id, "status": 502,
            "headers": {"content-type": "application/json"},
            "body_b64": base64.b64encode(json.dumps({"detail": "relay_local_error"}).encode()).decode("ascii"),
        })


class _Stream:
    """One tunnelled websocket, mirrored onto a loopback socket to ourselves."""

    def __init__(self, stream_id: str, path: str, query: str, send_json, send_frame):
        self.id = stream_id
        self.path = path
        self.query = query
        self.send_json = send_json
        self.send_frame = send_frame
        self.local = None

    async def run(self, on_done) -> None:
        url = "ws://127.0.0.1:%d%s%s" % (settings.school_server_port, self.path, "?" + self.query if self.query else "")
        try:
            async with websockets.connect(url, max_size=16 * 1024 * 1024) as local:
                self.local = local
                await self.send_json({"type": "ws_opened", "id": self.id})
                async for message in local:
                    if isinstance(message, (bytes, bytearray)):
                        await self.send_frame(self.id, b"b", bytes(message))
                    else:
                        await self.send_frame(self.id, b"t", message.encode("utf-8"))
        except Exception as exc:  # noqa: BLE001
            logger.debug("relay: stream %s ended: %s", self.id, exc)
        finally:
            self.local = None
            on_done()
            try:
                await self.send_json({"type": "ws_close", "id": self.id})
            except Exception:
                pass

    async def to_local(self, kind: bytes, data: bytes) -> None:
        if self.local is None:
            return
        try:
            await self.local.send(data if kind == b"b" else data.decode("utf-8", "replace"))
        except Exception:
            pass

    async def close(self) -> None:
        if self.local is not None:
            try:
                await self.local.close()
            except Exception:
                pass
