import threading
import time
from typing import Optional

import cv2

# What the live view is for: someone glancing at a phone to see the room is
# covered and the camera is pointed the right way. That does not need the
# camera's full frame at OpenCV's default JPEG quality of 95.
#
# Sized to a fixed width rather than to a fraction of the camera's own. The
# fraction was written for a 1280x720 camera, where halving it produced a
# 25 KB frame; the same rule against the 2560x1440 camera now installed
# produced 154 KB -- about 28 Mbit/s once the capture loop is running, which
# is more than a phone on wi-fi absorbs, and the picture froze and jumped
# rather than played. A rule in pixels holds whatever camera is bolted up
# next; a rule in halves silently gets four times worse.
#
# 960px at quality 65 measures 78 KB, and the cap below keeps it to 15 fps:
# roughly 9 Mbit/s, a third of what a phone was being asked to swallow.
#
# Detection is unaffected -- it works from the original frame (see
# live_detection.py), never from what is encoded here.
PREVIEW_MAX_WIDTH = 960
PREVIEW_JPEG_QUALITY = 65

# A room does not move fast enough to need every frame of a 25 fps camera,
# and the frames nobody can receive in time are the ones that arrive late
# and in bursts -- which is what stuttering actually is. Encoding fewer,
# further apart, is smoother than encoding all of them.
PREVIEW_MAX_FPS = 15
_MIN_FRAME_INTERVAL = 1.0 / PREVIEW_MAX_FPS

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
        self._last_encoded_at: dict[int, float] = {}
        self._viewers: dict[int, int] = {}
        self._viewers_lock = threading.Lock()

    def update_frame(self, frame, camera_id: int = 0):
        # Dropped before the resize, not after: skipping the encode is only
        # half the saving, and the resize of a 2560x1440 frame is the other
        # half of what this thread would otherwise spend.
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
                # Linear, not INTER_AREA. Area sampling gives a visibly
                # cleaner downscale and costs 31ms against this camera's
                # frame where linear costs 10 -- and insightface leaves
                # OpenCV on a single thread once its models load, which
                # takes area to 52ms and linear to 9. Measured inside the
                # running server, the resize and encode together were 85ms
                # a frame, on the same thread that has to keep reading: the
                # preview it produced was 5 fps. A preview nobody is
                # pixel-peeping does not need the better filter.
                interpolation=cv2.INTER_LINEAR,
            )
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
