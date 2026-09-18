import concurrent.futures
import cv2
import hashlib
import numpy as np

from app.utils.face_crypto import decrypt_text
import insightface
import threading
import time
from datetime import date, datetime, timedelta
from datetime import time as dt_time

from sqlalchemy.orm import Session

from app.database import SessionLocal

from app.models.camera_position_model import CameraPosition
from app.models.school_model import School
from app.models.student import Student
from app.services.camera_position_service import Slot, active_slot
from app.services.attendance_service import (
    DetectionCycleCounter,
    mark_absent_after_detection_cycles,
    mark_absent_for_lesson,
    mark_left_school_students,
    record_detection,
    record_lesson_detection,
)
from app.services.lesson_service import active_lesson_for_class
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


CAMERA_SOURCE = "rtsp://169.254.233.44:554/stream1?udp"

SIMILARITY_THRESHOLD = 0.40

MIN_MATCH_MARGIN = 0.08

ABSENT_AFTER_CYCLES = 2

_camera_status: dict[int, dict] = {}
_camera_status_lock = threading.Lock()


_watched_classes: dict[int, "date"] = {}


def set_camera_status(camera_id: int, **fields) -> None:
    with _camera_status_lock:
        current = _camera_status.setdefault(camera_id, {"camera_id": camera_id})
        current.update(fields)
        current["updated_at"] = time.time()
        if fields.get("connected"):
            current["last_connected_at"] = time.time()
            class_id = current.get("class_id")
            if class_id is not None:
                _watched_classes[int(class_id)] = datetime.now().date()


def classes_watched_on(day: "date") -> set[int]:
    with _camera_status_lock:
        return {cid for cid, d in _watched_classes.items() if d == day}


def camera_statuses() -> list[dict]:
    now = time.time()
    with _camera_status_lock:
        rows = [dict(row) for row in _camera_status.values()]

    for row in rows:
        next_at = row.pop("_next_detection_at", None)
        row["seconds_to_detect"] = (
            max(0, round(next_at - now)) if next_at else None
        )
        closes_at = row.pop("_arrival_closes_at", None)
        row["roll_call"] = bool(closes_at)
        row["seconds_to_roll_call_close"] = (
            max(0, round(closes_at - now)) if closes_at else None
        )
        started_at = row.pop("_detect_started_at", None)
        row["detecting_for"] = (
            round(now - started_at) if row.get("detecting") and started_at else None
        )
        row["stale_seconds"] = round(now - row.get("updated_at", now))
    return rows

_insight_app = None


def _get_insight_app():
    global _insight_app
    if _insight_app is None:
        _insight_app = insightface.app.FaceAnalysis(
            name="buffalo_l",
            providers=["CPUExecutionProvider"],
            allowed_modules=['detection', 'recognition'],
        )
        _insight_app.prepare(ctx_id=0, det_size=(960, 960))
    return _insight_app


_insight_lock = threading.Lock()


def _cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    denom = np.linalg.norm(a) * np.linalg.norm(b)
    if denom == 0:
        return 0.0
    return float(np.dot(a, b) / denom)


def _detect_faces_and_save(
    frame,
    known_encodings,
    known_students,
    camera_id: int,
    lesson_id: int | None = None,
    lesson_start: dt_time | None = None,
    lesson_seen: set[int] | None = None,
) -> None:
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

            if lesson_seen is not None and student.id in lesson_seen:
                continue

            save_attendance(
                db, student.id,
                camera_id=camera_id,
                confidence=best_score
            )
            if lesson_id is not None and lesson_start is not None:
                record_lesson_detection(
                    db,
                    student_id=student.id,
                    lesson_id=lesson_id,
                    lesson_start=lesson_start,
                    camera_id=camera_id,
                    confidence=best_score,
                )
                if lesson_seen is not None:
                    lesson_seen.add(student.id)
            print(f"[+] Camera {camera_id}: detected -> {student.first_name} (score: {best_score:.2f})")
    finally:
        db.close()

EMBEDDING_DIM = 512

FRAME_SKIP = 20

DETECTION_MIN_INTERVAL = 0.5

ARRIVAL_WINDOW_MINUTES = 10
ARRIVAL_SCAN_SECONDS = 10

ARRIVAL_MIN_LOOK_SECONDS = 60


def lesson_verdict_passed(db, lesson_id: int, day: date) -> bool:
    from app.models.lesson_attendance_model import LessonAttendance

    return (
        db.query(LessonAttendance)
        .filter(
            LessonAttendance.lesson_id == lesson_id,
            LessonAttendance.attendance_date == day,
            LessonAttendance.status == "absent",
        )
        .first()
        is not None
    )


def _lesson_present_count(db, lesson_id: int, day: date) -> int:
    from app.models.lesson_attendance_model import LessonAttendance

    return (
        db.query(LessonAttendance)
        .filter(
            LessonAttendance.lesson_id == lesson_id,
            LessonAttendance.attendance_date == day,
            LessonAttendance.status != "absent",
        )
        .count()
    )


def arrival_deadline_for(
    start: dt_time | None,
    now: float,
    today: date | None = None,
) -> float | None:
    if start is None:
        return None
    closes = datetime.combine(today or date.today(), start) + timedelta(
        minutes=ARRIVAL_WINDOW_MINUTES
    )
    deadline = closes.timestamp()
    if deadline <= now:
        return now + ARRIVAL_MIN_LOOK_SECONDS
    return deadline

DETECT_SECONDS = 10

WAIT_MINUTES = 20

RECONNECT_LEAD_SECONDS = 5

STAGGER_SECONDS_PER_CAMERA = 3
STAGGER_BUCKET = 30


def load_students(db: Session, class_id: int | None = None):

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
                        decrypt_text(student.face_encoding).split(",")
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


_detection_threads: list[threading.Thread] = []

def _run_camera(camera_id: int, camera_source: str):
    try:
        _run_camera_once(camera_id, camera_source)
    finally:
        _active_camera_ids.discard(camera_id)


def _run_camera_once(camera_id: int, camera_source: str):
    db = SessionLocal()

    def _class_from_positions(s, cam):
        now = datetime.now()
        rows = s.query(CameraPosition).filter(CameraPosition.camera_id == cam.id).all()
        slot = active_slot(
            [
                Slot(id=row.id, class_id=row.class_id, start_time=row.start_time,
                     end_time=row.end_time, day_of_week=row.day_of_week)
                for row in rows
            ],
            now.weekday(),
            now.strftime("%H:%M"),
        )
        return slot.class_id if slot else None

    def _load_config():
        s = SessionLocal()
        try:
            cam = s.query(Camera).filter(Camera.id == camera_id).first()
            if not cam:
                return DETECT_SECONDS, WAIT_MINUTES * 60, None

            school = s.query(School).filter(School.id == cam.school_id).first()
            if school is not None and school.group_mode:
                class_id = _class_from_positions(s, cam)
                if class_id is None:
                    return DETECT_SECONDS, WAIT_MINUTES * 60, None
                group = s.query(Class).filter(Class.id == class_id).first()
                if group is None:
                    return DETECT_SECONDS, WAIT_MINUTES * 60, None
                ds = group.detect_duration_seconds
                ds = DETECT_SECONDS if ds is None else ds
                ws = group.wait_duration_minutes
                ws = WAIT_MINUTES if ws is None else ws
                return ds, ws * 60, group.id

            if not cam.class_id:
                return DETECT_SECONDS, WAIT_MINUTES * 60, None
            school_class = s.query(Class).filter(Class.id == cam.class_id).first()
            if not school_class or not _in_time_window(
                school_class.start_time,
                school_class.end_time,
                school_class.timetable,
            ):
                return DETECT_SECONDS, WAIT_MINUTES * 60, None
            ds = school_class.detect_duration_seconds
            ds = DETECT_SECONDS if ds is None else ds
            ws = school_class.wait_duration_minutes
            ws = WAIT_MINUTES if ws is None else ws
            return ds, ws * 60, school_class.id
        finally:
            s.close()

    detect_seconds, wait_seconds, class_id = _load_config()

    def _load_roster(cid: int | None):
        return ([], []) if cid is None else load_students(db, cid)

    known_encodings, known_students = _load_roster(class_id)
    print(f"[+] Camera {camera_id}: loaded {len(known_students)} students for class_id={class_id}, source={camera_source}")

    def _load_active_lesson(cid: int | None):
        if cid is None:
            return None, None
        s = SessionLocal()
        try:
            lesson = active_lesson_for_class(s, cid)
            if lesson is None:
                return None, None
            try:
                hh, mm = map(int, lesson.start_time.split(":"))
            except (ValueError, AttributeError):
                return None, None
            return lesson.id, dt_time(hh, mm)
        finally:
            s.close()

    active_lesson_id, active_lesson_start = _load_active_lesson(class_id)
    lesson_seen: set[int] = set()

    lesson_cycles = 0

    arrival_finalised = (
        lesson_verdict_passed(db, active_lesson_id, date.today())
        if active_lesson_id is not None
        else False
    )
    arrival_opened_at = time.time()
    arrival_deadline: float | None = (
        arrival_deadline_for(active_lesson_start, arrival_opened_at)
        if active_lesson_id is not None and not arrival_finalised
        else None
    )

    def _refresh_lesson(cid: int | None) -> None:
        nonlocal active_lesson_id, active_lesson_start, lesson_seen, lesson_cycles
        nonlocal arrival_deadline, arrival_finalised, arrival_opened_at
        new_lesson_id, new_lesson_start = _load_active_lesson(cid)
        if new_lesson_id != active_lesson_id:
            active_lesson_id, active_lesson_start = new_lesson_id, new_lesson_start
            lesson_seen = set()
            lesson_cycles = 0
            arrival_finalised = (
                lesson_verdict_passed(db, new_lesson_id, date.today())
                if new_lesson_id is not None
                else False
            )
            arrival_opened_at = time.time()
            arrival_deadline = (
                arrival_deadline_for(new_lesson_start, arrival_opened_at)
                if new_lesson_id is not None and not arrival_finalised
                else None
            )
            if arrival_deadline is not None:
                print(f"[+] Camera {camera_id}: lesson {new_lesson_id} roll call open, "
                      f"closes in {int(arrival_deadline - time.time())}s")

    stagger_offset = (camera_id % STAGGER_BUCKET) * STAGGER_SECONDS_PER_CAMERA

    def _open():
        c = cv2.VideoCapture(camera_source)
        c.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        return c

    def _connect():
        with concurrent.futures.ThreadPoolExecutor() as ex:
            try:
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

    cycle_counter = DetectionCycleCounter(ABSENT_AFTER_CYCLES)
    detection_enabled = False
    next_detection_time = time.time() + stagger_offset if class_id is not None else 0.0

    detection_executor = concurrent.futures.ThreadPoolExecutor(max_workers=1)
    detection_future: concurrent.futures.Future | None = None
    last_detection_at = 0.0

    print(f"[+] Camera {camera_id}: detect={detect_seconds}s, wait={wait_seconds//60}m, stagger={stagger_offset}s, class_id={class_id}")

    consecutive_read_failures = 0
    last_frame_hash = None
    same_frame_count = 0
    while True:
        db.rollback()

        now = time.time()

        if now - last_refresh >= 60:
            detect_seconds, wait_seconds, new_class_id = _load_config()
            if new_class_id != class_id:
                became_active = class_id is None and new_class_id is not None
                class_id = new_class_id
                known_encodings, known_students = _load_roster(class_id)
                print(f"[+] Camera {camera_id}: active class changed -> class_id={class_id} ({len(known_students)} students)")
                if became_active:
                    detection_enabled = False
                    next_detection_time = now + stagger_offset
                elif class_id is None:
                    detection_enabled = False
                    next_detection_time = 0.0
            _refresh_lesson(class_id)
            last_refresh = now

        if class_id is None:
            if stream_manager.has_viewers(camera_id):
                if cap is None:
                    cap = _connect()
                    if cap is None:
                        time.sleep(2)
                        continue
                    consecutive_read_failures = 0
                    print(f"[+] Camera {camera_id}: connected for live view (no lesson)")
                ret, frame = cap.read()
                if ret:
                    stream_manager.update_frame(frame, camera_id=camera_id)
                else:
                    consecutive_read_failures += 1
                    if consecutive_read_failures >= 50:
                        cap.release()
                        cap = None
                        consecutive_read_failures = 0
                set_camera_status(camera_id, class_id=None, connected=True,
                                  detecting=False, phase="dars vaqti emas",
                                  _next_detection_at=None)
                continue

            if cap is not None:
                cap.release()
                cap = None
                print(f"[+] Camera {camera_id}: no active position, disconnected")
            set_camera_status(camera_id, class_id=None, connected=False,
                              detecting=False, phase="dars vaqti emas",
                              _next_detection_at=None)
            time.sleep(2)
            continue

        in_arrival = (
            active_lesson_id is not None
            and arrival_deadline is not None
            and not arrival_finalised
        )
        if (
            in_arrival
            and not detection_enabled
            and now < arrival_deadline
            and now >= arrival_opened_at + stagger_offset
        ):
            detection_enabled = True
            detect_start_time = now
            known_encodings, known_students = _load_roster(class_id)
            set_camera_status(camera_id, class_id=class_id, connected=True,
                              detecting=True, phase="ro'yxat",
                              roster=len(known_students),
                              seen=len(lesson_seen),
                              _detect_started_at=now,
                              _arrival_closes_at=arrival_deadline,
                              _next_detection_at=None)
            print(f"[+] Camera {camera_id}: roll call scanning "
                  f"({int(arrival_deadline - now)}s left, {len(known_students)} on the roster)")

        if not detection_enabled:
            time_until_detect = next_detection_time - now
            watching = stream_manager.has_viewers(camera_id)

            if watching:
                if cap is None:
                    cap = _connect()
                    if cap is None:
                        time.sleep(2)
                        continue
                    consecutive_read_failures = 0
                    same_frame_count = 0
                    last_frame_hash = None
                    print(f"[+] Camera {camera_id}: connected for live view")
                ret, frame = cap.read()
                if ret:
                    stream_manager.update_frame(frame, camera_id=camera_id)
                else:
                    consecutive_read_failures += 1
                    if consecutive_read_failures >= 50:
                        cap.release()
                        cap = None
                        consecutive_read_failures = 0
                        print(f"[-] Camera {camera_id}: live view stream lost, reconnecting")
                if now >= next_detection_time:
                    detection_enabled = True
                    detect_start_time = now
                    known_encodings, known_students = load_students(db, class_id)
                    _refresh_lesson(class_id)
                    print(f"[+] Camera {camera_id}: detection resumed")
                continue

            if time_until_detect > RECONNECT_LEAD_SECONDS:
                if cap is not None:
                    cap.release()
                    cap = None
                    print(f"[+] Camera {camera_id}: waiting ({int(time_until_detect)}s), disconnected")
                set_camera_status(camera_id, class_id=class_id, connected=False,
                                  detecting=False, phase="kutish",
                                  roster=len(known_students),
                                  _next_detection_at=next_detection_time)
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
                _refresh_lesson(class_id)
                print(f"[+] Camera {camera_id}: detection resumed")
                set_camera_status(camera_id, class_id=class_id, connected=True,
                                  detecting=True, phase="qidirilmoqda",
                                  roster=len(known_students),
                                  _detect_started_at=now,
                                  _next_detection_at=None)
            else:
                time.sleep(0.5)
            continue

        if cap is None:
            cap = _connect()
            if cap is None:
                time.sleep(2)
                continue
            consecutive_read_failures = 0
            same_frame_count = 0
            last_frame_hash = None

        ret, frame = cap.read()
        if not ret:
            consecutive_read_failures += 1
            if consecutive_read_failures >= 50:
                print(f"[-] Camera {camera_id}: lost stream, reconnecting ({camera_source})")
                cap.release()
                cap = None
                consecutive_read_failures = 0
            continue
        consecutive_read_failures = 0

        frame_hash = hashlib.md5(frame[::16, ::16].tobytes()).digest()
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

        scan_interval = ARRIVAL_SCAN_SECONDS if in_arrival else DETECTION_MIN_INTERVAL
        if (detection_future is None or detection_future.done()) and (
            now - last_detection_at >= scan_interval
        ):
            last_detection_at = now
            if in_arrival:
                set_camera_status(camera_id, class_id=class_id, connected=True,
                                  detecting=True, phase="ro'yxat",
                                  roster=len(known_students),
                                  seen=len(lesson_seen),
                                  _arrival_closes_at=arrival_deadline,
                                  _next_detection_at=None)
            detection_future = detection_executor.submit(
                _detect_faces_and_save,
                frame.copy(),
                known_encodings,
                known_students,
                camera_id,
                active_lesson_id,
                active_lesson_start,
                lesson_seen,
            )

        roll_call_closing = in_arrival and now >= arrival_deadline
        if roll_call_closing or (not in_arrival and elapsed >= detect_seconds):
            detection_enabled = False
            next_detection_time = now + wait_seconds
            print(f"[+] Camera {camera_id}: AI paused for {wait_seconds//60} minutes...")
            set_camera_status(camera_id, class_id=class_id, connected=False,
                              detecting=False, phase="kutish",
                              roster=len(known_students),
                              seen=len(lesson_seen),
                              _arrival_closes_at=None,
                              _next_detection_at=next_detection_time)
            mark_left_school_students(db)

            today = date.today()

            if roll_call_closing:
                arrival_finalised = True
                cycle_counter.record(today)
                if class_id is not None:
                    day_absent = mark_absent_after_detection_cycles(db, class_id, today)
                    lesson_absent = (
                        mark_absent_for_lesson(db, class_id, active_lesson_id, today)
                        if active_lesson_id is not None else []
                    )
                    present = (
                        _lesson_present_count(db, active_lesson_id, today)
                        if active_lesson_id is not None else 0
                    )
                    print(f"[+] Camera {camera_id}: roll call closed -- "
                          f"{present} present, {len(lesson_absent)} newly absent from the "
                          f"lesson, {len(day_absent)} newly absent for the day")

            enough_passes = cycle_counter.record(today)
            if not roll_call_closing and enough_passes and class_id is not None:
                marked = mark_absent_after_detection_cycles(db, class_id, today)
                if marked:
                    print(f"[+] Camera {camera_id}: cycle {cycle_counter.count}, "
                          f"marked {len(marked)} absent")

            if (
                class_id is not None
                and active_lesson_id is not None
                and arrival_deadline is None
                and not arrival_finalised
            ):
                lesson_cycles += 1
                if lesson_cycles >= ABSENT_AFTER_CYCLES:
                    missing = mark_absent_for_lesson(db, class_id, active_lesson_id, today)
                    if missing:
                        print(f"[+] Camera {camera_id}: lesson {active_lesson_id} "
                              f"sweep {lesson_cycles}, marked {len(missing)} absent")

            known_encodings, known_students = _load_roster(class_id)
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
