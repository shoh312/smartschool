import asyncio

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect

from app.deps import get_current_director_ws
from app.websocket.manager import manager
from app.stream.stream_manager import stream_manager

router = APIRouter(tags=["websocket"])


@router.websocket("/ws/attendance")
async def attendance_websocket(
    websocket: WebSocket,
    _director=Depends(get_current_director_ws),
):
    await manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)


@router.websocket("/ws/stream")
async def stream_websocket(
    websocket: WebSocket,
    camera_id: int = 0,
    _director=Depends(get_current_director_ws),
):
    await websocket.accept()
    # Tells the camera thread somebody is actually watching, so it keeps the
    # stream open instead of dropping it between detection windows -- which
    # is what made the live view run for ten seconds and then freeze.
    stream_manager.add_viewer(camera_id)
    try:
        last_frame: bytes | None = None
        while True:
            frame = await stream_manager.get_frame(camera_id=camera_id)
            if frame is not None and frame is not last_frame:
                await websocket.send_bytes(frame)
                last_frame = frame
            await asyncio.sleep(0.05)
    except WebSocketDisconnect:
        pass
    finally:
        # Must run on every exit path, not just a clean disconnect: a viewer
        # left counted forever would pin the camera open for the rest of the
        # server's life.
        stream_manager.remove_viewer(camera_id)
