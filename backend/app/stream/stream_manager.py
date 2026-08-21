import threading
from typing import Optional

import cv2

# What the live view is for: someone glancing at a phone to see the room is
# covered and the camera is pointed the right way. That does not need the
# camera's full frame at OpenCV's default JPEG quality of 95 -- measured on
# the installed 1280x720 camera, that was 197 KB a frame, roughly 16 Mbit/s
# once the capture loop is running, and 4ms of encoding on the same thread
# that has to keep reading frames.
#
# Half size at quality 70 measures 25 KB and 1ms: eight times less to push
# over the socket and four times less work to produce it, for a preview that
# still reads clearly on a phone.
#
# Detection is unaffected -- it works from the original frame (see
# live_detection.py), never from what is encoded here.
PREVIEW_SCALE = 0.5
PREVIEW_JPEG_QUALITY = 70

_ENCODE_PARAMS = [int(cv2.IMWRITE_JPEG_QUALITY), PREVIEW_JPEG_QUALITY]


class StreamManager:
    """Latest preview frame per camera, plus who is currently watching.

    The viewer count exists because streaming and detection want opposite
    things from the camera connection. Detection wants it open for ten
    seconds and closed the rest of the time -- decoding video nobody is
    looking at is the single most wasteful thing this server could do. A
    person watching the live view wants exactly the opposite.

    Reconciling them by guessing (longer windows, shorter waits) trades one
    complaint for the other. Counting viewers answers the question directly:
    the capture loop keeps the stream open while someone is actually
    watching, and goes back to its duty cycle the moment they close it.

    Counts are touched from the asyncio request handlers and read from the
    camera threads, hence the lock.
    """

    def __init__(self):
        self._frames: dict[int, bytes] = {}
        self._viewers: dict[int, int] = {}
        self._viewers_lock = threading.Lock()

    def update_frame(self, frame, camera_id: int = 0):
        if PREVIEW_SCALE != 1.0:
            frame = cv2.resize(frame, (0, 0), fx=PREVIEW_SCALE, fy=PREVIEW_SCALE)
        ok, buffer = cv2.imencode('.jpg', frame, _ENCODE_PARAMS)
        if not ok:
            return
        self._frames[camera_id] = buffer.tobytes()

    async def get_frame(self, camera_id: int = 0) -> Optional[bytes]:
        return self._frames.get(camera_id)

    # -- viewers ----------------------------------------------------------

    def add_viewer(self, camera_id: int = 0) -> None:
        with self._viewers_lock:
            self._viewers[camera_id] = self._viewers.get(camera_id, 0) + 1

    def remove_viewer(self, camera_id: int = 0) -> None:
        with self._viewers_lock:
            remaining = self._viewers.get(camera_id, 0) - 1
            if remaining > 0:
                self._viewers[camera_id] = remaining
            else:
                # Never let it go negative: a disconnect that somehow fires
                # twice would otherwise leave the count below zero and stop
                # the next real viewer from being seen at all.
                self._viewers.pop(camera_id, None)

    def has_viewers(self, camera_id: int = 0) -> bool:
        with self._viewers_lock:
            return self._viewers.get(camera_id, 0) > 0


stream_manager = StreamManager()
