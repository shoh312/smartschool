import concurrent.futures
import cv2
import hashlib
import numpy as np
import insightface
import threading
import time

from sqlalchemy.orm import Session

from app.database import SessionLocal

from app.models.student import Student
from app.services.attendance_service import (
    mark_left_school_students,
    record_detection,
)
def _class_window_end_time(start_str: str | None, end_str: str | None, timetable: dict | None) -> str | None:
    from datetime import datetime, timedelta
    if not start_str:
        return end_str
    day_key = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"][datetime.now().weekday()]
    if timetable:
        entries = timetable.get(day_key) or []
    else:
        return end_str
    total_minutes = 0
    for entry in entries:
        if isinstance(entry, dict):
            try:
                total_minutes += int(entry.get("duration_minutes") or 45)
            except (TypeError, ValueError):
                total_minutes += 45
    if total_minutes <= 0:
        return end_str
    try:
        sh, sm = map(int, start_str.split(':'))
    except (ValueError, IndexError):
        return end_str
    end_dt = datetime.now().replace(hour=sh, minute=sm, second=0, microsecond=0) + timedelta(minutes=total_minutes)
    return end_dt.strftime("%H:%M")


def _in_time_window(start_str: str | None, end_str: str | None, timetable: dict | None = None) -> bool:
    from datetime import datetime
    effective_end_str = _class_window_end_time(start_str, end_str, timetable)
    if not start_str:
        return True
    if not effective_end_str:
        return False
    try:
        now = datetime.now()
        sh, sm = map(int, start_str.split(':'))
        eh, em = map(int, effective_end_str.split(':'))
        start_s = sh * 3600 + sm * 60
        end_s = eh * 3600 + em * 60
        now_s = now.hour * 3600 + now.minute * 60
        if start_s <= end_s:
            return start_s <= now_s < end_s
        else:
            return now_s >= start_s or now_s < end_s
    except (ValueError, IndexError):
        return True

from app.models.camera_model import Camera
from app.models.class_model import Class
from app.models.parent_model import Parent
from app.models.notification_model import (
    NotificationEvent,
    DeviceToken
)

from app.stream.stream_manager import stream_manager

# SETTINGS

CAMERA_SOURCE = "rtsp://169.254.233.44:554/stream1?udp"

# Cosine similarity threshold: 0.0-1.0, yuqoriroq = qattiqroq
SIMILARITY_THRESHOLD = 0.42

# Tuned for rosters of up to ~25 known faces per class. A flat threshold
# alone gets less reliable as the roster grows -- two different students can
# both plausibly clear SIMILARITY_THRESHOLD, and without this check the
# highest-scoring one wins even when the runner-up was a near-tie (i.e. the
# match wasn't actually confident, just relatively best). Requiring the
# winner to beat the runner-up by this much cosine-similarity rejects those
# too-close-to-call frames instead of guessing -- the next detection cycle
# a few seconds later gets another chance.
MIN_MATCH_MARGIN = 0.08

_insight_app = None


def _get_insight_app():
    global _insight_app
    if _insight_app is None:
        _insight_app = insightface.app.FaceAnalysis(
            name="buffalo_l",
            providers=["CPUExecutionProvider"]
        )
        # 960x960 instead of the model's default 640x640 -- a camera mounted
        # front-center in a ~10m classroom needs to still resolve faces in
        # the back row, which occupy far fewer pixels than someone standing
        # close to the lens. This is a real compute cost increase (roughly
        # (960/640)^2 = 2.25x the detector's per-call work) -- see
        # _detect_faces_and_save's resize factor, which has to grow together
        # with this or there's no extra real detail for the larger det_size
        # to use.
        _insight_app.prepare(ctx_id=0, det_size=(960, 960))
    return _insight_app


# All cameras share one insightface model instance (loading it per-camera
# would multiply memory/startup cost). It's a single ONNX runtime session,
# so concurrent .get() calls from two cameras' detection workers at once
# aren't safe -- this lock serializes just the inference call itself, not
# frame capture, so it never blocks the live view.
_insight_lock = threading.Lock()


def _cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    denom = np.linalg.norm(a) * np.linalg.norm(b)
    if denom == 0:
        return 0.0
    return float(np.dot(a, b) / denom)


def _detect_faces_and_save(frame, known_encodings, known_students, camera_id: int) -> None:
    """Runs on a dedicated per-camera worker thread (see `detection_executor`
    in `_run_camera_once`) so the CPU-heavy insightface call never blocks
    that camera's frame-capture loop. Opens its own DB session -- a
    SQLAlchemy session isn't safe to share with the capture loop's session,
    which keeps running concurrently on the main camera thread.
    """
    # 0.5 instead of a smaller factor -- a 10m-deep classroom needs the back
    # row's faces to still have enough real pixels left after this resize
    # for the 960x960 detector (see _get_insight_app) to find them. Shrinking
    # more aggressively than this throws away detail the larger det_size
    # exists to use, and just re-upscales a blurry frame internally instead.
    small_frame = cv2.resize(frame, (0, 0), fx=0.5, fy=0.5)

    insight = _get_insight_app()
    with _insight_lock:
        detected_faces = insight.get(small_frame)

    if not detected_faces or not known_encodings:
        return

    db = SessionLocal()
    try:
        for face in detected_faces:
            embedding = face.embedding
            scores = [_cosine_similarity(embedding, enc) for enc in known_encodings]
            best_idx = int(np.argmax(scores))
            best_score = scores[best_idx]

            if best_score < SIMILARITY_THRESHOLD:
                continue

            if len(scores) > 1:
                runner_up = max(s for i, s in enumerate(scores) if i != best_idx)
                if best_score - runner_up < MIN_MATCH_MARGIN:
                    print(
                        f"[!] Camera {camera_id}: ambiguous match "
                        f"(best={best_score:.2f}, runner-up={runner_up:.2f}) -- skipping"
                    )
                    continue

            student = known_students[best_idx]
            save_attendance(
                db, student.id,
                camera_id=camera_id,
                confidence=best_score
            )
            print(f"[+] Camera {camera_id}: detected -> {student.first_name} (score: {best_score:.2f})")
    finally:
        db.close()

# insightface's buffalo_l model always outputs a 512-d embedding. A handful
# of students in this DB were registered by an older face-encoding pipeline
# (128-d, dlib-based) before the project switched to insightface -- comparing
# a 512-d live embedding against one of those crashes the whole detection
# thread (np.dot shape mismatch), which then silently drops every other
# student's comparison too and freezes the live stream until the watcher
# restarts the thread. Filter those out in load_students() instead of
# crashing on them.
EMBEDDING_DIM = 512

# Each detection call briefly holds Python's GIL during insightface
# inference, which can stall unrelated API requests on the same process
# while it's running. The 960x960/0.5x combination above (tuned for a 10m
# classroom) costs noticeably more per call than the original 640x640/0.35x
# setup -- if that stall grows large enough to be felt on a given machine,
# raising FRAME_SKIP (fewer attempts, same 15s detect window) is the knob to
# use rather than shrinking det_size/the resize factor back down, which
# would just lose the back row again.
FRAME_SKIP = 20

DETECT_SECONDS = 10

WAIT_MINUTES = 20

# A camera's RTSP connection is only held open for its own detect window
# (plus this much lead time to warm up) -- disconnected the rest of the
# time. With a typical 15s-detect/20min-wait duty cycle that's over 99% of
# the time spent decoding a video stream nobody's using it for anything.
# The tradeoff: live view only works while a camera happens to be
# connected for its own detect window.
RECONNECT_LEAD_SECONDS = 5

# When a RoomPosition's start_time is reached, every camera whose position
# starts at that same clock time (e.g. a whole school's first shift at
# 08:00) would otherwise reconnect and start detecting in the same instant.
# Spreading each camera's actual start across a few seconds (by camera_id)
# turns that synchronized spike into a short ramp, which is what a machine
# needs to be sized for -- not the burst. Wraps at STAGGER_BUCKET cameras so
# the max one-time delay stays small (here, under 90s) regardless of how
# many cameras a school has.
STAGGER_SECONDS_PER_CAMERA = 3
STAGGER_BUCKET = 30

# LOAD STUDENTS


def load_students(db: Session, class_id: int | None = None):
    """`class_id` scopes recognition to one class's roster -- a camera should
    only ever be compared against the students it's actually pointed at, not
    every student with a face encoding across every class and school.
    `None` keeps the old unscoped behavior, used only by the no-camera-in-DB
    fallback in `_ensure_cameras`, which has no real class to scope to.
    """

    query = db.query(Student).filter(Student.face_encoding != None)
    if class_id is not None:
        query = query.filter(Student.class_id == class_id)
    students = query.all()

    known_encodings = []

    known_students = []

    for student in students:

        try:

            encoding = np.array(
                list(
                    map(
                        float,
                        student.face_encoding.split(",")
                    )
                )
            )

            if encoding.shape[0] != EMBEDDING_DIM:
                print(
                    f"[!] Student {student.id} ({student.first_name} {student.last_name}): "
                    f"face encoding has {encoding.shape[0]} dims, expected {EMBEDDING_DIM} "
                    "(stale/incompatible encoding) -- skipping until re-registered"
                )
                continue

            known_encodings.append(
                encoding
            )

            known_students.append(student)

        except:
            pass

    return known_encodings, known_students


# _in_time_window / _active_position_for_room live in room_schedule_service
# (shared with attendance_service.py, which also needs "which position is
# active now" for its own present-vs-late cutoff -- see that module for why
# it isn't defined here). Callers of _active_position_for_room must treat a
# None result as "no known students", not fall back to load_students' own
# None-means-everyone behavior (see call sites).

# SAVE ATTENDANCE


def save_attendance(
    db,
    student_id,
    camera_id=None,
    confidence=1.0
):
    attendance = record_detection(
        db,
        student_id=student_id,
        camera_id=camera_id,
        confidence=confidence,
    )

    print(f"[+] Attendance {attendance.status} updated")

# START DETECTION

_detection_threads: list[threading.Thread] = []

def _run_camera(camera_id: int, camera_source: str):
    try:
        _run_camera_once(camera_id, camera_source)
    finally:
        # However the loop below exits (timeout, disconnect, error), drop this
        # camera from the active set so the watcher's next pass restarts it
        # instead of believing it's still running forever.
        _active_camera_ids.discard(camera_id)


def _run_camera_once(camera_id: int, camera_source: str):
    db = SessionLocal()

    def _load_config():
        s = SessionLocal()
        try:
            cam = s.query(Camera).filter(Camera.id == camera_id).first()
            if not cam or not cam.class_id:
                return DETECT_SECONDS, WAIT_MINUTES * 60, None
            school_class = s.query(Class).filter(Class.id == cam.class_id).first()
            if not school_class or not _in_time_window(
                school_class.start_time,
                school_class.end_time,
                school_class.timetable,
            ):
                return DETECT_SECONDS, WAIT_MINUTES * 60, None
            ds = (school_class.detect_duration_seconds if school_class.detect_duration_seconds is not None else None) or DETECT_SECONDS
            ws = ((school_class.wait_duration_minutes if school_class.wait_duration_minutes is not None else None) or WAIT_MINUTES) * 60
            return ds, ws, school_class.id
        finally:
            s.close()

    detect_seconds, wait_seconds, class_id = _load_config()

    def _load_roster(cid: int | None):
        return ([], []) if cid is None else load_students(db, cid)

    known_encodings, known_students = _load_roster(class_id)
    print(f"[+] Camera {camera_id}: loaded {len(known_students)} students for class_id={class_id}, source={camera_source}")

    stagger_offset = (camera_id % STAGGER_BUCKET) * STAGGER_SECONDS_PER_CAMERA

    def _open():
        c = cv2.VideoCapture(camera_source)
        c.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        return c

    def _connect():
        with concurrent.futures.ThreadPoolExecutor() as ex:
            try:
                # OpenCV's own ffmpeg RTSP connect timeout defaults to ~30s,
                # so the outer guard must be longer than that or it fires
                # first and kills a connection attempt that would have
                # succeeded.
                c = ex.submit(_open).result(timeout=35)
            except concurrent.futures.TimeoutError:
                print(f"[-] Camera {camera_id}: timeout connecting ({camera_source})")
                return None
        if not c.isOpened():
            print(f"[-] Camera {camera_id}: cannot open {camera_source}")
            return None
        return c

    cap = None
    last_refresh = time.time()
    frame_count = 0
    detect_start_time = time.time()
    # Not connecting eagerly here even if a position is already active --
    # every camera whose position happens to start at the same clock time
    # (or every camera at all, on a server restart) goes through the same
    # staggered wait-then-connect path below instead of all reconnecting in
    # the same instant.
    detection_enabled = False
    next_detection_time = time.time() + stagger_offset if class_id is not None else 0.0

    # One detection in flight at a time for this camera -- see the dispatch
    # site below for why (never blocks frame capture; skips rather than
    # queues if the previous detection is still running).
    detection_executor = concurrent.futures.ThreadPoolExecutor(max_workers=1)
    detection_future: concurrent.futures.Future | None = None

    print(f"[+] Camera {camera_id}: detect={detect_seconds}s, wait={wait_seconds//60}m, stagger={stagger_offset}s, class_id={class_id}")

    consecutive_read_failures = 0
    last_frame_hash = None
    same_frame_count = 0
    while True:
        now = time.time()

        if now - last_refresh >= 60:
            detect_seconds, wait_seconds, new_class_id = _load_config()
            if new_class_id != class_id:
                became_active = class_id is None and new_class_id is not None
                class_id = new_class_id
                known_encodings, known_students = _load_roster(class_id)
                print(f"[+] Camera {camera_id}: active class changed -> class_id={class_id} ({len(known_students)} students)")
                if became_active:
                    # A new position just started covering this room --
                    # stagger this camera's reconnect instead of jumping
                    # straight to detecting (see stagger_offset above).
                    detection_enabled = False
                    next_detection_time = now + stagger_offset
                elif class_id is None:
                    detection_enabled = False
                    next_detection_time = 0.0
            last_refresh = now

        if class_id is None:
            if cap is not None:
                cap.release()
                cap = None
                print(f"[+] Camera {camera_id}: no active position, disconnected")
            time.sleep(2)
            continue

        if not detection_enabled:
            time_until_detect = next_detection_time - now
            if time_until_detect > RECONNECT_LEAD_SECONDS:
                if cap is not None:
                    cap.release()
                    cap = None
                    print(f"[+] Camera {camera_id}: waiting ({int(time_until_detect)}s), disconnected")
                time.sleep(1)
                continue
            if cap is None:
                cap = _connect()
                if cap is None:
                    time.sleep(2)
                    continue
                consecutive_read_failures = 0
                same_frame_count = 0
                last_frame_hash = None
                print(f"[+] Camera {camera_id}: reconnected ahead of detect window")
            if now >= next_detection_time:
                detection_enabled = True
                detect_start_time = now
                known_encodings, known_students = load_students(db, class_id)
                print(f"[+] Camera {camera_id}: detection resumed")
            else:
                time.sleep(0.5)
            continue

        # detection_enabled: must be connected and actively capturing.
        if cap is None:
            cap = _connect()
            if cap is None:
                time.sleep(2)
                continue
            consecutive_read_failures = 0
            same_frame_count = 0
            last_frame_hash = None

        for _ in range(3):
            cap.grab()
        ret, frame = cap.read()
        if not ret:
            consecutive_read_failures += 1
            if consecutive_read_failures >= 50:
                # Stream dropped mid-run (flaky link, camera reboot, etc).
                # Reconnect inline instead of tearing down the whole thread
                # -- the loop above will retry _connect() on the next pass.
                print(f"[-] Camera {camera_id}: lost stream, reconnecting ({camera_source})")
                cap.release()
                cap = None
                consecutive_read_failures = 0
            continue
        consecutive_read_failures = 0

        # A live feed's frames are never byte-identical across reads (sensor
        # noise, compression artifacts) -- if the exact same bytes come back
        # repeatedly, the decoder has silently stalled while still reporting
        # ret=True (a soft freeze), which the read-failure counter above
        # can't see. Detect it separately and force the same reconnect path.
        frame_hash = hashlib.md5(frame.tobytes()).digest()
        if frame_hash == last_frame_hash:
            same_frame_count += 1
            if same_frame_count >= 90:
                print(f"[-] Camera {camera_id}: frozen stream, reconnecting ({camera_source})")
                cap.release()
                cap = None
                same_frame_count = 0
                continue
        else:
            same_frame_count = 0
            last_frame_hash = frame_hash

        stream_manager.update_frame(frame, camera_id=camera_id)

        elapsed = now - detect_start_time
        if frame_count % FRAME_SKIP != 0:
            frame_count += 1
            continue
        frame_count += 1

        # Face recognition is CPU-heavy (hundreds of ms per call) -- running
        # it inline here used to block this same loop's frame capture, so
        # the live view visibly froze/stuttered for the whole detect
        # window. Hand it to a dedicated worker instead and keep grabbing
        # frames immediately; if the previous detection hasn't finished yet,
        # skip this one rather than queue a backlog or block waiting for it.
        if detection_future is None or detection_future.done():
            detection_future = detection_executor.submit(
                _detect_faces_and_save,
                frame.copy(),
                known_encodings,
                known_students,
                camera_id,
            )

        if elapsed >= detect_seconds:
            detection_enabled = False
            next_detection_time = now + wait_seconds
            print(f"[+] Camera {camera_id}: AI paused for {wait_seconds//60} minutes...")
            mark_left_school_students(db)
            known_encodings, known_students = _load_roster(class_id)
            # No need to keep the stream open through the whole wait window
            # -- the "not detection_enabled" branch above reconnects on its
            # own shortly before the next detect window.
            cap.release()
            cap = None


_active_camera_ids: set[int] = set()

def _ensure_cameras():
    global _detection_threads, _active_camera_ids
    db = SessionLocal()
    try:
        from app.models.camera_model import Camera
        cameras = db.query(Camera).filter(Camera.is_active == True).all()
    finally:
        db.close()

    for cam in cameras:
        if cam.id in _active_camera_ids:
            continue
        src = cam.rtsp_url or CAMERA_SOURCE
        t = threading.Thread(target=_run_camera, args=(cam.id, src), daemon=True)
        t.start()
        _detection_threads.append(t)
        _active_camera_ids.add(cam.id)
        print(f"[+] Camera {cam.id}: detection thread started")

    if not _active_camera_ids:
        print("[+] No active cameras in DB, using default")
        class _FakeCamera:
            id = 0
            rtsp_url = CAMERA_SOURCE
        _ensure_one_camera = _FakeCamera()
        t = threading.Thread(target=_run_camera, args=(_ensure_one_camera.id, _ensure_one_camera.rtsp_url), daemon=True)
        t.start()
        _detection_threads.append(t)
        _active_camera_ids.add(0)

    print(f"[+] Total {len(_active_camera_ids)} camera(s) active")


def start_detection_background():
    _ensure_cameras()

    def _camera_watcher():
        while True:
            time.sleep(10)
            _ensure_cameras()

    threading.Thread(target=_camera_watcher, daemon=True).start()
    print("[+] Camera watcher started (checks every 10s)")
