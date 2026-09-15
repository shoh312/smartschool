import threading
import time
from typing import Optional

import cv2

PREVIEW_MAX_WIDTH = 960
PREVIEW_JPEG_QUALITY = 65

PREVIEW_MAX_FPS = 15
_MIN_FRAME_INTERVAL = 1.0 / PREVIEW_MAX_FPS

_ENCODE_PARAMS = [int(cv2.IMWRITE_JPEG_QUALITY), PREVIEW_JPEG_QUALITY]


class StreamManager:

    def __init__(self):
        self._frames: dict[int, bytes] = {}
        self._last_encoded_at: dict[int, float] = {}
        self._viewers: dict[int, int] = {}
        self._viewers_lock = threading.Lock()

    def update_frame(self, frame, camera_id: int = 0):
        now = time.monotonic()
        if now - self._last_encoded_at.get(camera_id, 0.0) < _MIN_FRAME_INTERVAL:
            return
        self._last_encoded_at[camera_id] = now

        height, width = frame.shape[:2]
        if width > PREVIEW_MAX_WIDTH:
            scale = PREVIEW_MAX_WIDTH / width
            frame = cv2.resize(
                frame,
                (PREVIEW_MAX_WIDTH, max(1, int(round(height * scale)))),
                interpolation=cv2.INTER_LINEAR,
            )
        ok, buffer = cv2.imencode('.jpg', frame, _ENCODE_PARAMS)
        if not ok:
            return
        self._frames[camera_id] = buffer.tobytes()

    async def get_frame(self, camera_id: int = 0) -> Optional[bytes]:
        return self._frames.get(camera_id)


    def add_viewer(self, camera_id: int = 0) -> None:
        with self._viewers_lock:
            self._viewers[camera_id] = self._viewers.get(camera_id, 0) + 1

    def remove_viewer(self, camera_id: int = 0) -> None:
        with self._viewers_lock:
            remaining = self._viewers.get(camera_id, 0) - 1
            if remaining > 0:
                self._viewers[camera_id] = remaining
            else:
                self._viewers.pop(camera_id, None)

    def has_viewers(self, camera_id: int = 0) -> bool:
        with self._viewers_lock:
            return self._viewers.get(camera_id, 0) > 0


stream_manager = StreamManager()
