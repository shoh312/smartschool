import cv2
import numpy as np
import insightface
import time
from datetime import datetime

from sqlalchemy.orm import Session

from app.database import SessionLocal

from app.models.student import Student
from app.services.attendance_service import (
    mark_left_school_students,
    record_detection,
)

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
SIMILARITY_THRESHOLD = 0.4

_insight_app = None


def _get_insight_app():
    global _insight_app
    if _insight_app is None:
        _insight_app = insightface.app.FaceAnalysis(
            name="buffalo_l",
            providers=["CPUExecutionProvider"]
        )
        _insight_app.prepare(ctx_id=0, det_size=(640, 640))
    return _insight_app


def _cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    denom = np.linalg.norm(a) * np.linalg.norm(b)
    if denom == 0:
        return 0.0
    return float(np.dot(a, b) / denom)

FRAME_SKIP = 10

DETECT_SECONDS = 10

WAIT_MINUTES = 20

# LOAD STUDENTS


def load_students(db: Session):

    students = db.query(Student).filter(
        Student.face_encoding != None
    ).all()

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

            known_encodings.append(
                encoding
            )

            known_students.append(student)

        except:
            pass

    return known_encodings, known_students

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

# =====================================================
# START DETECTION
# =====================================================

def start_detection(camera_source=CAMERA_SOURCE, camera_id=None):

    db = SessionLocal()

    known_encodings, known_students = load_students(db)

    print(
        f"[+] Loaded {len(known_students)} students"
    )

    cap = cv2.VideoCapture(camera_source)
    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
    frame_count = 0

    detection_enabled = True

    detect_start_time = time.time()

    next_detection_time = 0

    print("\n[+] Camera started")

    while True:

        for _ in range(3):
            cap.grab()

        ret, frame = cap.read()

        if not ret:
            continue

        cv2.imshow(
            "SmartSchool AI",
            frame
        )

        stream_manager.update_frame(frame)

        key = cv2.waitKey(1)

        if key == ord("q"):

            cap.release()

            cv2.destroyAllWindows()

            return

        current_time = time.time()

        # WAIT MODE

        if not detection_enabled:

            remaining = int(
                next_detection_time - current_time
            )

            cv2.putText(

                frame,

                f"AI Paused: {remaining}s",

                (20, 40),

                cv2.FONT_HERSHEY_SIMPLEX,

                1,

                (0, 0, 255),

                2
            )

            cv2.imshow(
                "SmartSchool AI",
                frame
            )

            if current_time >= next_detection_time:

                detection_enabled = True

                detect_start_time = time.time()

                known_encodings, known_students = load_students(db)

                print("\n[+] Detection resumed")

            continue

        # DETECT MODE
        

        elapsed = current_time - detect_start_time

        cv2.putText(

            frame,

            "AI Detecting...",

            (20, 40),

            cv2.FONT_HERSHEY_SIMPLEX,

            1,

            (0, 255, 0),

            2
        )

        if frame_count % FRAME_SKIP != 0:

            frame_count += 1

            continue

        frame_count += 1

        small_frame = cv2.resize(frame, (0, 0), fx=0.5, fy=0.5)

        insight = _get_insight_app()
        detected_faces = insight.get(small_frame)

        for face in detected_faces:
            if not known_encodings:
                continue

            embedding = face.embedding
            scores = [_cosine_similarity(embedding, enc) for enc in known_encodings]
            best_idx = int(np.argmax(scores))
            best_score = scores[best_idx]

            if best_score < SIMILARITY_THRESHOLD:
                continue

            student = known_students[best_idx]

            save_attendance(
                db,
                student.id,
                camera_id=camera_id,
                confidence=best_score
            )

            print(f"[+] Detected -> {student.first_name} (score: {best_score:.2f})")

        # DETECTION FINISHED

        if elapsed >= DETECT_SECONDS:

            detection_enabled = False

            next_detection_time = (
                time.time()
                + WAIT_MINUTES * 60
            )

            print(
                f"\n[+] AI paused for "
                f"{WAIT_MINUTES} minutes..."
            )

            mark_left_school_students(db)

            known_encodings, known_students = load_students(db)


# START DETECTION

import threading
import concurrent.futures

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
    known_encodings, known_students = load_students(db)
    print(f"[+] Camera {camera_id}: loaded {len(known_students)} students, source={camera_source}")

    def _open():
        c = cv2.VideoCapture(camera_source)
        c.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        return c

    cap = None
    with concurrent.futures.ThreadPoolExecutor() as ex:
        try:
            # OpenCV's own ffmpeg RTSP connect timeout defaults to ~30s, so
            # the outer guard must be longer than that or it fires first and
            # kills a connection attempt that would have succeeded.
            cap = ex.submit(_open).result(timeout=35)
        except concurrent.futures.TimeoutError:
            print(f"[-] Camera {camera_id}: timeout ({camera_source})")
            db.close()
            return

    if not cap.isOpened():
        print(f"[-] Camera {camera_id}: cannot open {camera_source}")
        db.close()
        return

    def _load_config():
        s = SessionLocal()
        try:
            cam = s.query(Camera).filter(Camera.id == camera_id).first()
            if not cam:
                return DETECT_SECONDS, WAIT_MINUTES * 60, None, None
            ds = cam.detect_duration_seconds or DETECT_SECONDS
            ws = (cam.wait_duration_minutes or WAIT_MINUTES) * 60
            return ds, ws, cam.detection_start_time, cam.detection_end_time
        finally:
            s.close()

    def _in_schedule(start_str: str | None, end_str: str | None) -> bool:
        if not start_str or not end_str:
            return True
        try:
            now = datetime.now()
            sh, sm = map(int, start_str.split(':'))
            eh, em = map(int, end_str.split(':'))
            start_s = sh * 3600 + sm * 60
            end_s = eh * 3600 + em * 60
            now_s = now.hour * 3600 + now.minute * 60
            if start_s <= end_s:
                return start_s <= now_s < end_s
            else:
                return now_s >= start_s or now_s < end_s
        except (ValueError, IndexError):
            return True

    detect_seconds, wait_seconds, start_str, end_str = _load_config()
    last_refresh = time.time()

    frame_count = 0
    detection_enabled = _in_schedule(start_str, end_str)
    detect_start_time = time.time()
    next_detection_time = 0.0

    print(f"[+] Camera {camera_id}: schedule={start_str}-{end_str}, detect={detect_seconds}s, wait={wait_seconds//60}m, started={'in-schedule' if detection_enabled else 'outside-schedule'}")

    consecutive_read_failures = 0
    while True:
        for _ in range(3):
            cap.grab()
        ret, frame = cap.read()
        if not ret:
            consecutive_read_failures += 1
            if consecutive_read_failures >= 50:
                # Stream dropped mid-run (flaky link, camera reboot, etc).
                # Give up so the watcher restarts this camera with a fresh
                # connection instead of spinning here forever.
                print(f"[-] Camera {camera_id}: lost stream, reconnecting ({camera_source})")
                cap.release()
                db.close()
                return
            continue
        consecutive_read_failures = 0

        stream_manager.update_frame(frame, camera_id=camera_id)
        now = time.time()

        if now - last_refresh >= 60:
            detect_seconds, wait_seconds, start_str, end_str = _load_config()
            last_refresh = now

        if not _in_schedule(start_str, end_str):
            if detection_enabled:
                detection_enabled = False
                next_detection_time = 0.0
                print(f"[+] Camera {camera_id}: outside schedule ({start_str}-{end_str}), AI off")
            continue

        if not detection_enabled:
            if now >= next_detection_time:
                detection_enabled = True
                detect_start_time = now
                known_encodings, known_students = load_students(db)
                print(f"[+] Camera {camera_id}: detection resumed")
            continue

        elapsed = now - detect_start_time
        if frame_count % FRAME_SKIP != 0:
            frame_count += 1
            continue
        frame_count += 1

        small_frame = cv2.resize(frame, (0, 0), fx=0.5, fy=0.5)

        insight = _get_insight_app()
        detected_faces = insight.get(small_frame)

        for face in detected_faces:
            if not known_encodings:
                continue

            embedding = face.embedding
            scores = [_cosine_similarity(embedding, enc) for enc in known_encodings]
            best_idx = int(np.argmax(scores))
            best_score = scores[best_idx]

            if best_score < SIMILARITY_THRESHOLD:
                continue

            student = known_students[best_idx]
            save_attendance(
                db, student.id,
                camera_id=camera_id,
                confidence=best_score
            )
            print(f"[+] Camera {camera_id}: detected -> {student.first_name} (score: {best_score:.2f})")

        if elapsed >= detect_seconds:
            detection_enabled = False
            next_detection_time = now + wait_seconds
            print(f"[+] Camera {camera_id}: AI paused for {wait_seconds//60} minutes...")
            mark_left_school_students(db)
            known_encodings, known_students = load_students(db)


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