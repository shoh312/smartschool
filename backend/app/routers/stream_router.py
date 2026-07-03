import asyncio
from fastapi import APIRouter, Response
from fastapi.responses import StreamingResponse
from app.stream.stream_manager import stream_manager

router = APIRouter(prefix="/stream", tags=["Stream"])

async def frame_generator():
    while True:
        frame = await stream_manager.get_frame()
        if frame:
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')
        await asyncio.sleep(0.1)

@router.get("/live")
async def video_feed():
    return StreamingResponse(
        frame_generator(),
        media_type="multipart/x-mixed-replace; boundary=frame"
    )

@router.get("/frame")
async def get_frame(camera_id: int = 0):
    frame = await stream_manager.get_frame(camera_id=camera_id)
    if frame is None:
        return Response(status_code=204)
    return Response(content=frame, media_type="image/jpeg")
