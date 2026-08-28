import concurrent.futures
import cv2
import hashlib
import numpy as np
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

# SETTINGS

CAMERA_SOURCE = "rtsp://169.254.233.44:554/stream1?udp"

# Cosine similarity threshold: 0.0-1.0, yuqoriroq = qattiqroq
#
# Lowered from 0.42 to 0.40 for the beta, deliberately and with the cost
# understood: a lower bar recognises pupils further from the lens and in
# worse light, and it also lets two similar faces clear it. What stops that
# turning into "marked the wrong child present" is MIN_MATCH_MARGIN below --
# a match still has to beat the runner-up by a clear margin, so a borderline
# face that resembles two pupils equally is rejected rather than guessed.
#
# Raise it back towards 0.45 once the school reports a wrong name; that is
# the failure this trades against, and it is worse than a missed detection
# because a parent is told their child arrived when they did not.
SIMILARITY_THRESHOLD = 0.40

# Tuned for rosters of up to ~25 known faces per class. A flat threshold
# alone gets less reliable as the roster grows -- two different students can
# both plausibly clear SIMILARITY_THRESHOLD, and without this check the
# highest-scoring one wins even when the runner-up was a near-tie (i.e. the
# match wasn't actually confident, just relatively best). Requiring the
# winner to beat the runner-up by this much cosine-similarity rejects those
# too-close-to-call frames instead of guessing -- the next detection cycle
# a few seconds later gets another chance.
MIN_MATCH_MARGIN = 0.08

# How many completed detect windows before an unseen student counts as
# absent. One is not enough: a child walking through the door, or turned
# away from the lens for those ten seconds, is missed by a single sweep, and
# marking them absent on that basis sends their parent a false alarm. Two
# passes means the room has genuinely been looked at twice.
ABSENT_AFTER_CYCLES = 2

# What each camera thread is doing right now, so it can be watched from
# outside without reading the process's stdout.
#
# Only the loop itself knows where it is in its cycle -- whether the stream
# is open, whether recognition is running, how long until the next window.
# Anything watching from outside would otherwise have to infer that from
# detections appearing in the database, which says nothing at all on a
# morning when nobody has arrived yet.
_camera_status: dict[int, dict] = {}
_camera_status_lock = threading.Lock()


def set_camera_status(camera_id: int, **fields) -> None:
    with _camera_status_lock:
        current = _camera_status.setdefault(camera_id, {"camera_id": camera_id})
        current.update(fields)
        current["updated_at"] = time.time()


def camera_statuses() -> list[dict]:
    """A snapshot, with the countdowns worked out as of this moment."""
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
            # FaceAnalysis runs every module in the pack by default, and this
            # project reads exactly two things off a face: `embedding` (here)
            # and `bbox` (face_engine). The 2D/3D landmark and age/gender
            # models were being run once per detected face and thrown away --
            # 59ms of the 189ms each face cost, so a third of the work in a
            # classroom, spent on nothing.
            #
            # Verified before switching: with these dropped the embeddings
            # come out bit-identical (max difference 0.0 across a 6-face test
            # image), so no student has to be re-registered. Recognition
            # aligns from the detector's own 5 keypoints, not from these.
            allowed_modules=['detection', 'recognition'],
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


def _detect_faces_and_save(
    frame,
    known_encodings,
    known_students,
    camera_id: int,
    lesson_id: int | None = None,
    lesson_start: dt_time | None = None,
    lesson_seen: set[int] | None = None,
) -> None:
    """Runs on a dedicated per-camera worker thread (see `detection_executor`
    in `_run_camera_once`) so the CPU-heavy insightface call never blocks
    that camera's frame-capture loop. Opens its own DB session -- a
    SQLAlchemy session isn't safe to share with the capture loop's session,
    which keeps running concurrently on the main camera thread.

    `lesson_id`/`lesson_start`/`lesson_seen` describe the lesson currently in
    session for this camera's class (see `active_lesson_for_class` in
    `_run_camera_once`) -- once a student is in `lesson_seen`, this function
    stops writing attendance for them (day- and lesson-level both) until the
    caller clears the set for a new lesson, satisfying "don't re-detect this
    student again until the lesson ends."
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

# Shortest gap between two detection passes.
#
# The worker skips a pass while the previous one is still running, which
# stops a backlog but not saturation: each pass ends and the next begins,
# so a ten-second window is ten seconds of every core at full tilt. The
# capture thread sharing that machine fell from 24 fps to 8, and the live
# view visibly froze for the length of every window -- and the detector
# itself, measured against this camera, slowed from 193ms when the machine
# was free to over 3 seconds when it was fighting itself.
#
# Half a second between passes still gives roughly twenty looks at the room
# per window, far more than the two cycles it takes to call somebody
# absent, and each look is now the fast kind. Slower in name, more
# recognitions in practice, and a preview that keeps moving.
DETECTION_MIN_INTERVAL = 0.5

# The roll call at the start of a lesson.
#
# The duty cycle alone answers "is the room occupied" well and "who turned
# up for this lesson" badly: ten seconds of looking, then twenty minutes of
# nothing, so a pupil who arrives at 14:02 and sits with their back to the
# lens at 14:00 is called absent on the strength of one glance, and the
# correction only comes at 14:20 -- long after their parent was told.
#
# So the first ten minutes of every lesson are treated differently: the
# camera stays on and looks once every ten seconds, roughly sixty looks at
# the room, and the verdict is passed once at the end of it. That is when a
# register is actually decided in a classroom, and it is late enough that
# somebody walking in from the corridor is still counted as having come.
#
# After it closes the ordinary cycle takes over unchanged -- ten seconds of
# detection every twenty minutes -- and it never calls anyone absent again
# for that lesson. A pupil seen during the roll call has arrived, and the
# rest of the lesson cannot take that back.
ARRIVAL_WINDOW_MINUTES = 10
ARRIVAL_SCAN_SECONDS = 10

# When the camera picks up a lesson whose roll call has already run out --
# the server was restarted mid-lesson, the camera reconnected late -- the
# window is not simply skipped. Nobody has looked at this room yet, so it
# gets this long to look before it is allowed to call anybody absent.
ARRIVAL_MIN_LOOK_SECONDS = 60


def lesson_verdict_passed(db, lesson_id: int, day: date) -> bool:
    """Has this lesson's register already been decided today?

    An absence can only be written by a roll call closing (or by the bell,
    once the lesson is over) -- a camera never writes one on its own. So one
    absent row is proof the verdict has been passed, and it is proof that
    survives a restart, which the in-memory flag does not.

    Without this, every restart during a lesson opened a fresh roll call and
    judged the class again. A pupil enrolled after the first verdict was
    marked absent a minute later; one already marked absent had their parent
    told twice. The register is meant to be decided once.
    """
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
    """How many pupils the register credits with attending this lesson."""
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
    """When a lesson's roll call closes, as epoch seconds.

    Pure so the rule can be tested without a camera or a clock. Returns None
    for a lesson with no start time -- there is nothing to anchor a roll call
    to, and the caller falls back to counting sweeps instead.
    """
    if start is None:
        return None
    closes = datetime.combine(today or date.today(), start) + timedelta(
        minutes=ARRIVAL_WINDOW_MINUTES
    )
    deadline = closes.timestamp()
    if deadline <= now:
        # The window is already spent -- the server restarted mid-lesson, or
        # the camera reconnected late. Nobody has looked at this room yet, so
        # it gets a short look before it is allowed to call anyone absent,
        # rather than passing a verdict on no evidence at all.
        return now + ARRIVAL_MIN_LOOK_SECONDS
    return deadline

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

    def _class_from_positions(s, cam):
        """Whose group is in this room right now, in group mode.

        A school gives every class its own room, so a camera belongs to a
        class and the class's own timetable is the window. An academy runs
        Python 4 through a room at nine and Java 2 through the same room at
        two -- a camera bound to one class would recognise one group and mark
        the other absent every day, silently. So here the camera belongs to
        the room, and the slot in force decides whose faces to load.

        Returns None outside every slot, which idles the camera exactly the
        way being outside lesson hours does.
        """
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
                # The slot is the window here, so the class's own start_time
                # and timetable are not consulted -- only its duty cycle.
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
            # `or` would be wrong here: a director who sets the wait to 0
            # means "never pause", and `0 or WAIT_MINUTES` silently hands
            # them the twenty-minute default instead -- the exact opposite.
            # Only a missing value should fall back.
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
    # Which students have already been recorded for the currently active
    # lesson -- cleared below whenever the resolved lesson changes, so a
    # student is only re-processed once the next lesson starts.
    lesson_seen: set[int] = set()

    # Sweeps completed inside the lesson that is running now. Counted per
    # lesson rather than per day (the day-level counter below is a separate
    # thing) because every lesson is its own register: a pupil present for
    # Maths and gone by Physics has to be marked absent from Physics, and
    # that cannot be decided by how many times the room was looked at since
    # morning.
    lesson_cycles = 0

    # When this lesson's roll call closes, and whether its verdict has been
    # passed. Both reset with the bell, below.
    #
    # Seeded from the lesson resolved above, not left empty for the first
    # refresh to fill in. The refresh only reacts to the lesson *changing*,
    # so a thread that starts up mid-lesson -- which is every restart during
    # the school day -- saw no change, opened no roll call, and quietly fell
    # back to the old two-sweep rule for the rest of that lesson.
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
            # Back to zero with the bell: the next lesson gets its own two
            # sweeps before anyone is called absent from it.
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

    # How many detect windows this camera has completed today. Rolling the
    # count over at midnight is what stops a counter left from yesterday
    # branding a class absent on the first sweep of the morning.
    cycle_counter = DetectionCycleCounter(ABSENT_AFTER_CYCLES)
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
    last_detection_at = 0.0

    print(f"[+] Camera {camera_id}: detect={detect_seconds}s, wait={wait_seconds//60}m, stagger={stagger_offset}s, class_id={class_id}")

    consecutive_read_failures = 0
    last_frame_hash = None
    same_frame_count = 0
    while True:
        # Ends whatever transaction the previous pass opened.
        #
        # This session lives as long as the camera thread does -- weeks --
        # and every read through it starts a transaction that SQLAlchemy
        # leaves open until something commits or rolls back. Nothing here
        # did, so the session sat "idle in transaction" indefinitely, and
        # every ALTER TABLE in the startup migrations queued behind it. The
        # visible symptom was the whole app hanging with no error: requests
        # blocked behind a migration that was blocked behind a camera.
        #
        # Rolling back is right rather than committing: writes here go
        # through their own sessions in attendance_service, so there is never
        # anything of ours to keep.
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
                    # A new position just started covering this room --
                    # stagger this camera's reconnect instead of jumping
                    # straight to detecting (see stagger_offset above).
                    detection_enabled = False
                    next_detection_time = now + stagger_offset
                elif class_id is None:
                    detection_enabled = False
                    next_detection_time = 0.0
            _refresh_lesson(class_id)
            last_refresh = now

        if class_id is None:
            # Nobody is timetabled into the room, so there is nobody to
            # recognise -- but a director asking to see the room is a
            # different question from whether a lesson is running. The camera
            # used to disconnect outright here, so opening the live view out
            # of hours showed nothing at all and looked like a broken stream
            # rather than an empty schedule.
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

        # The roll call outranks the duty cycle. While it is open the camera
        # is not waiting for its next twenty-minute slot -- the lesson has
        # just begun and this is the only stretch that decides who came.
        in_arrival = (
            active_lesson_id is not None
            and arrival_deadline is not None
            and not arrival_finalised
        )
        # Staggered even here. The roll call is time-critical but ten
        # minutes long, so spending a camera's own few seconds of offset on
        # it costs nothing, and a school with several cameras still does not
        # reconnect all of them on the same tick of the clock.
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
                # Somebody has the live view open. Keep the stream running
                # and keep publishing frames -- just don't recognise anyone,
                # which is the expensive half and is what the duty cycle
                # exists to ration. Without this the picture froze the
                # moment a detection window closed, for as long as the wait
                # lasted (a minute, by default twenty).
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

        # detection_enabled: must be connected and actively capturing.
        if cap is None:
            cap = _connect()
            if cap is None:
                time.sleep(2)
                continue
            consecutive_read_failures = 0
            same_frame_count = 0
            last_frame_hash = None

        # No pre-grab. Discarding a frame to stay current only helps a loop
        # that has fallen behind the camera -- and grabbing was what put it
        # behind. cv2.read() is already grab+retrieve, so the pair decoded
        # two 2560x1440 frames to keep one: measured against this camera,
        # 13.5 fps for grab+read against 29.6 fps for read alone.
        #
        # At 13.5 against a 25 fps camera the backlog grew by eleven frames
        # a second and the drain never caught up, which is what the preview
        # freezing and jumping actually was. Reading flat out outruns the
        # camera, so there is nothing to drain in the first place.
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
        # Hashed from every 16th pixel, not the whole frame. A 2560x1440
        # frame is 11 MB, and md5 over all of it ran on the same thread that
        # has to keep reading frames -- paid on every single pass, purely to
        # notice a stall. The subsample still changes constantly on a live
        # feed and still stops dead on a frozen one, which is all this needs
        # to tell apart.
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

        # Face recognition is CPU-heavy (hundreds of ms per call) -- running
        # it inline here used to block this same loop's frame capture, so
        # the live view visibly froze/stuttered for the whole detect
        # window. Hand it to a dedicated worker instead and keep grabbing
        # frames immediately; if the previous detection hasn't finished yet,
        # skip this one rather than queue a backlog or block waiting for it.
        # One look every ten seconds during the roll call, not as fast as the
        # machine allows. Sixty unhurried looks over ten minutes find a class
        # more reliably than a burst that saturates the CPU, and they leave
        # the live view watchable while they do it.
        scan_interval = ARRIVAL_SCAN_SECONDS if in_arrival else DETECTION_MIN_INTERVAL
        if (detection_future is None or detection_future.done()) and (
            now - last_detection_at >= scan_interval
        ):
            last_detection_at = now
            if in_arrival:
                # Refreshed on every look so anything watching from outside
                # can see the register filling up rather than only its total
                # at the end.
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

        # The roll call ends on the clock, not after detect_seconds: it runs
        # for its whole ten minutes and closes when the lesson is ten minutes
        # old. Every window after it is an ordinary one.
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

            # One pass is not evidence of absence -- a child walking in, or
            # turned away from the lens, is missed by the first sweep and
            # would be branded absent on the strength of a single look. From
            # the second pass on, the room has been checked twice and anyone
            # still unseen is genuinely not there.
            today = date.today()

            if roll_call_closing:
                # The verdict, passed once. Ten minutes and some sixty looks
                # at the room are far more evidence than the two sweeps the
                # counter below waits for, so the day-level register is
                # settled here too and the parents of anyone missing are told
                # now rather than after the next twenty-minute wait.
                arrival_finalised = True
                # The roll call counts as one of the day's sweeps; the
                # unconditional record below is the second, which leaves the
                # day counter satisfied so a later window does not start the
                # two-sweep count from scratch.
                cycle_counter.record(today)
                if class_id is not None:
                    day_absent = mark_absent_after_detection_cycles(db, class_id, today)
                    lesson_absent = (
                        mark_absent_for_lesson(db, class_id, active_lesson_id, today)
                        if active_lesson_id is not None else []
                    )
                    # Read back off the register rather than counting what
                    # this window happened to see. A thread that started
                    # mid-lesson has an empty seen-set and would report "0
                    # present" for a class it had just filled in correctly,
                    # which reads as a failure and is not one.
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

            # The same two-sweep rule, applied to the lesson in progress so
            # the subject's own register fills in while the lesson is still
            # running. One sweep proves nothing here either -- a pupil who
            # walked in during the previous minute, or who had their back to
            # the lens, is missed by a single look.
            # Only ever a fallback now. A lesson whose roll call has closed
            # has had its answer, and no later sweep may overturn it: a pupil
            # counted in during the first ten minutes came to school, whether
            # or not the lens finds them again at twenty past. This runs for
            # a lesson that never had a roll call at all -- no start time to
            # anchor one to -- where two sweeps remain the best evidence
            # available.
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
