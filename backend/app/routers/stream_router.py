import asyncio
from fastapi import APIRouter, Depends, HTTPException, Response
from fastapi.responses import StreamingResponse
from app.database import get_db
from app.deps import get_current_director
from app.models.director_model import Director
from app.models.school_model import School
from sqlalchemy.orm import Session
from app.stream.stream_manager import stream_manager

router = APIRouter(prefix="/stream", tags=["Stream"], dependencies=[Depends(get_current_director)])


async def frame_generator(camera_id: int = 0):
    # Counted as a viewer for the same reason the WebSocket is: an MJPEG
    # client is watching just as much, and without this the camera would
    # keep dropping the stream between detection windows underneath it.
    stream_manager.add_viewer(camera_id)
    try:
        while True:
            frame = await stream_manager.get_frame(camera_id=camera_id)
            if frame:
                yield (b'--frame\r\n'
                       b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')
            await asyncio.sleep(0.1)
    finally:
        # Runs when the client goes away and the generator is closed.
        stream_manager.remove_viewer(camera_id)


def _require_live_enabled(db: Session, director: Director) -> None:
    """The director's switch, enforced here and not only in the app."""
    school = db.query(School).filter(School.id == director.school_id).first()
    if school is not None and not school.live_video_enabled:
        raise HTTPException(status_code=403, detail='live_video_disabled')


@router.get("/live")
async def video_feed(
    camera_id: int = 0,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    _require_live_enabled(db, director)
    return StreamingResponse(
        frame_generator(camera_id),
        media_type="multipart/x-mixed-replace; boundary=frame"
    )


@router.get("/frame")
async def get_frame(
    camera_id: int = 0,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    _require_live_enabled(db, director)
    frame = await stream_manager.get_frame(camera_id=camera_id)
    if frame is None:
        return Response(status_code=204)
    return Response(content=frame, media_type="image/jpeg")
