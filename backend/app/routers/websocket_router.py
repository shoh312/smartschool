import asyncio

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_director_ws
from app.models.school_model import School
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
    director=Depends(get_current_director_ws),
    db: Session = Depends(get_db),
):
    school = db.query(School).filter(School.id == director.school_id).first()
    if school is not None and not school.live_video_enabled:
        await websocket.accept()
        await websocket.close(code=1008, reason='live_video_disabled')
        return

    await websocket.accept()
    stream_manager.add_viewer(camera_id)
    try:
        last_frame: bytes | None = None
        while True:
            frame = await stream_manager.get_frame(camera_id=camera_id)
            if frame is not None and frame is not last_frame:
                await websocket.send_bytes(frame)
                last_frame = frame
            await asyncio.sleep(0.015)
    except WebSocketDisconnect:
        pass
    finally:
        stream_manager.remove_viewer(camera_id)


import hmac as _hmac
from datetime import datetime as _dt

from app.models.camera_model import Camera
from app.models.camera_position_model import CameraPosition
from app.models.class_model import Class


def _camera_for_class_now(db: Session, class_id: int) -> int | None:
    now = _dt.now()
    hm = now.strftime("%H:%M")
    dow = now.weekday()
    for p in db.query(CameraPosition).filter(CameraPosition.class_id == class_id).all():
        if p.day_of_week is not None and p.day_of_week != dow:
            continue
        if p.start_time[:5] <= hm < p.end_time[:5]:
            return p.camera_id
    cls = db.query(Class).filter(Class.id == class_id).first()
    if cls is not None and cls.start_time and cls.end_time and str(cls.start_time)[:5] <= hm < str(cls.end_time)[:5]:
        cam = db.query(Camera).filter(Camera.class_id == class_id, Camera.is_active == True).first()
        if cam is not None:
            return cam.id
    return None


@router.websocket("/ws/parent-stream")
async def parent_stream_websocket(websocket: WebSocket, class_id: int = 0, secret: str = "", db: Session = Depends(get_db)):
    from app import relay_client

    await websocket.accept()
    expected = relay_client.current_relay_secret
    if not expected or not secret or not _hmac.compare_digest(secret, expected):
        await websocket.close(code=1008, reason="forbidden")
        return
    school = db.query(School).first()
    if school is not None and not school.live_video_enabled:
        await websocket.close(code=1008, reason="live_video_disabled")
        return
    camera_id = _camera_for_class_now(db, class_id)
    if camera_id is None:
        await websocket.close(code=1008, reason="no_lesson")
        return

    stream_manager.add_viewer(camera_id)
    try:
        last_frame: bytes | None = None
        while True:
            frame = await stream_manager.get_frame(camera_id=camera_id)
            if frame is not None and frame is not last_frame:
                await websocket.send_bytes(frame)
                last_frame = frame
            await asyncio.sleep(0.015)
    except WebSocketDisconnect:
        pass
    finally:
        stream_manager.remove_viewer(camera_id)
