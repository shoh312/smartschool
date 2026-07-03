import cv2
import asyncio
from typing import Optional

class StreamManager:
    def __init__(self):
        self._frames: dict[int, bytes] = {}
        self._lock = asyncio.Lock()

    def update_frame(self, frame, camera_id: int = 0):
        _, buffer = cv2.imencode('.jpg', frame)
        self._frames[camera_id] = buffer.tobytes()

    async def get_frame(self, camera_id: int = 0) -> Optional[bytes]:
        return self._frames.get(camera_id)

stream_manager = StreamManager()
