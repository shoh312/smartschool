import asyncio
from fastapi import APIRouter, Depends, Response
from fastapi.responses import StreamingResponse
from app.deps import get_current_director
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


@router.get("/live")
async def video_feed(camera_id: int = 0):
    return StreamingResponse(
        frame_generator(camera_id),
        media_type="multipart/x-mixed-replace; boundary=frame"
    )


@router.get("/frame")
async def get_frame(camera_id: int = 0):
    frame = await stream_manager.get_frame(camera_id=camera_id)
    if frame is None:
        return Response(status_code=204)
    return Response(content=frame, media_type="image/jpeg")
