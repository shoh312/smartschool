from datetime import date, datetime, time, timedelta

from sqlalchemy.orm import Session

from app.models.attendance_model import Attendance
from app.models.lesson_attendance_model import LessonAttendance
from app.models.camera_position_model import CameraPosition
from app.models.lesson_model import Lesson
from app.models.student import Student
from app.notifications.firebase import create_notification_event
from app.realtime import broadcast_attendance_update
from app.services.camera_position_service import ABSENCE_GRACE_MINUTES, Slot, classes_with_started_slot
from app.services.lesson_service import finished_lessons_today
from app.services.sync_outbox_service import enqueue_attendance_event
from app.utils.config import settings

PRESENT = "present"
ABSENT = "absent"
LEFT_SCHOOL = "left_school"
LATE = "late"


def _status_for_detection(detected_at: datetime, class_start_time: time | None = None) -> str:
    if class_start_time is None:
        class_start_time = settings.attendance_late_after
    start_min = class_start_time.hour * 60 + class_start_time.minute
    grace_min = start_min + 15
    grace_time = time(grace_min // 60 % 24, grace_min % 60)
    return PRESENT if detected_at.time() <= grace_time else LATE


def get_daily_attendance(db: Session, student_id: int, day: date) -> Attendance | None:
    return db.query(Attendance).filter(
        Attendance.student_id == student_id,
        Attendance.attendance_date == day,
    ).first()


def _class_start_from_camera(db: Session, camera_id: int) -> time | None:
    from app.models.camera_model import Camera
    from app.models.class_model import Class

    cam = db.query(Camera).filter(Camera.id == camera_id).first()
    if not cam:
        return None

    if not cam.class_id:
        return _slot_start_for_camera(db, cam.id)

    school_class = db.query(Class).filter(Class.id == cam.class_id).first()
    if school_class and school_class.start_time:
        try:
            parts = school_class.start_time.split(':')
            return time(int(parts[0]), int(parts[1]))
        except (ValueError, IndexError):
            pass
    return None


def _slot_start_for_camera(db: Session, camera_id: int, now: datetime | None = None) -> time | None:
    from app.models.camera_position_model import CameraPosition
    from app.services.camera_position_service import Slot, active_slot

    now = now or datetime.now()
    rows = db.query(CameraPosition).filter(CameraPosition.camera_id == camera_id).all()
    slots = [
        Slot(
            class_id=row.class_id,
            start_time=row.start_time,
            end_time=row.end_time,
            day_of_week=row.day_of_week,
            id=row.id,
        )
        for row in rows
    ]
    slot = active_slot(slots, now.weekday(), now.strftime("%H:%M"))
    if slot is None:
        return None
    try:
        hours, minutes = slot.start_time.split(":")
        return time(int(hours), int(minutes))
    except (ValueError, IndexError):
        return None


def record_detection(
    db: Session,
    student_id: int,
    camera_id: int | None = None,
    confidence: float | None = 1.0,
    detected_at: datetime | None = None,
) -> Attendance:
    detected_at = detected_at or datetime.now()
    today = detected_at.date()

    from app.models.school_model import School

    student_school_id = db.query(Student.school_id).filter(Student.id == student_id).scalar()
    if student_school_id is not None:
        school = db.query(School).filter(School.id == student_school_id).first()
        if school and not school.is_active:
            return Attendance(
                student_id=student_id,
                camera_id=camera_id,
                status="school_paused",
                attendance_date=today,
            )

    attendance = get_daily_attendance(db, student_id, today)
    class_start = _class_start_from_camera(db, camera_id) if camera_id is not None else None

    if attendance:
        attendance.camera_id = camera_id or attendance.camera_id
        attendance.confidence = confidence if confidence is not None else attendance.confidence
        attendance.last_seen = detected_at
        attendance.time_out = detected_at
        attendance.updated_at = detected_at
        if attendance.status in (ABSENT, LEFT_SCHOOL):
            attendance.status = _status_for_detection(detected_at, class_start)
            attendance.time_in = attendance.time_in or detected_at
            
            student = db.query(Student).filter(Student.id == student_id).first()
            if student:
                create_notification_event(
                    db,
                    event_type=attendance.status,
                    title="Фарзандатон омад",
                    body=f"Фарзандатон {student.first_name} {student.last_name} ба мактаб омад.",
                    parent_id=student.parent_id,
                    student_id=student.id,
                    attendance_id=attendance.id,
                )
        db.flush()
        enqueue_attendance_event(db, attendance, operation="upsert")
        db.commit()
        db.refresh(attendance)
        broadcast_attendance_update()
        return attendance

    attendance = Attendance(
        student_id=student_id,
        camera_id=camera_id,
        status=_status_for_detection(detected_at, class_start),
        confidence=confidence,
        attendance_date=today,
        time_in=detected_at,
        time_out=detected_at,
        last_seen=detected_at,
        detected_at=detected_at,
    )
    db.add(attendance)
    db.flush()
    enqueue_attendance_event(db, attendance, operation="upsert")
    db.commit()
    db.refresh(attendance)

    student = db.query(Student).filter(Student.id == student_id).first()
    if student:
        create_notification_event(
            db,
            event_type=attendance.status,
            title="Фарзандатон омад",
            body=f"Фарзандатон {student.first_name} {student.last_name} ба мактаб омад.",
            parent_id=student.parent_id,
            student_id=student.id,
            attendance_id=attendance.id,
        )

    broadcast_attendance_update()
    return attendance


def classes_in_session_on(lessons, weekday: int, clock: str | None = None, grace_minutes: int = 0) -> set[int]:
    def _m(hhmm: str) -> int:
        h, m = (hhmm or "00:00")[:5].split(":")
        return int(h) * 60 + int(m)

    return {
        lesson.class_id
        for lesson in lessons
        if lesson.day_of_week == weekday
        and (clock is None or _m(lesson.start_time or "00:00") + grace_minutes <= _m(clock))
    }


def mark_absent_students(
    db: Session,
    day: date | None = None,
    cutoff: time | None = None,
) -> list[Attendance]:
    now = datetime.now()
    day = day or now.date()
    cutoff = cutoff or settings.attendance_late_after

    if day == now.date() and now.time() < cutoff:
        return []

    clock = now.strftime("%H:%M") if day == now.date() else "23:59"
    in_session = classes_in_session_on(db.query(Lesson).all(), day.weekday(), clock, grace_minutes=ABSENCE_GRACE_MINUTES)

    in_session |= classes_with_started_slot(
        [
            Slot(id=row.id, class_id=row.class_id, start_time=row.start_time,
                 end_time=row.end_time, day_of_week=row.day_of_week)
            for row in db.query(CameraPosition).all()
        ],
        day.weekday(),
        clock,
    )

    if not in_session:
        return []

    from app.ai.live_detection import classes_watched_on

    in_session &= classes_watched_on(day)
    if not in_session:
        return []

    from app.models.class_model import Class
    from app.models.school_model import School

    inactive_school_ids = {
        row[0] for row in db.query(School.id).filter(School.is_active == False).all()
    }
    if inactive_school_ids:
        paused_class_ids = {
            row[0] for row in db.query(Class.id).filter(Class.school_id.in_(inactive_school_ids)).all()
        }
        in_session -= paused_class_ids
        if not in_session:
            return []

    active_students = db.query(Student).filter(
        Student.is_active == True,
        Student.class_id.in_(in_session),
    ).all()
    created = []

    for student in active_students:
        attendance = get_daily_attendance(db, student.id, day)
        if attendance:
            continue

        absent_record = Attendance(
            student_id=student.id,
            camera_id=None,
            status=ABSENT,
            attendance_date=day,
            detected_at=now,
        )
        db.add(absent_record)
        db.flush()
        enqueue_attendance_event(db, absent_record, operation="upsert")
        db.commit()
        db.refresh(absent_record)
        created.append(absent_record)

        create_notification_event(
            db,
            event_type=ABSENT,
            title="Фарзандатон ғоиб аст",
            body=f"Фарзандатон {student.first_name} {student.last_name} то соати 08:15 ба мактаб наомад.",
            parent_id=student.parent_id,
            student_id=student.id,
            attendance_id=absent_record.id,
        )

    return created


class DetectionCycleCounter:

    def __init__(self, threshold: int, today: date | None = None):
        self.threshold = threshold
        self._day = today or date.today()
        self._count = 0

    @property
    def count(self) -> int:
        return self._count

    def record(self, day: date | None = None) -> bool:
        day = day or date.today()
        if day != self._day:
            self._day = day
            self._count = 0
        self._count += 1
        return self._count >= self.threshold


def mark_absent_after_detection_cycles(
    db: Session,
    class_id: int,
    day: date | None = None,
) -> list[Attendance]:
    now = datetime.now()
    day = day or now.date()

    students = db.query(Student).filter(
        Student.class_id == class_id,
        Student.is_active == True,
    ).all()

    created = []
    for student in students:
        if get_daily_attendance(db, student.id, day):
            continue

        absent_record = Attendance(
            student_id=student.id,
            camera_id=None,
            status=ABSENT,
            attendance_date=day,
            detected_at=now,
        )
        db.add(absent_record)
        db.flush()
        enqueue_attendance_event(db, absent_record, operation="upsert")
        db.commit()
        db.refresh(absent_record)
        created.append(absent_record)

        create_notification_event(
            db,
            event_type=ABSENT,
            title="Фарзандатон ғоиб аст",
            body=f"Фарзандатон {student.first_name} {student.last_name} имрӯз дар синф пайдо нашуд.",
            parent_id=student.parent_id,
            student_id=student.id,
            attendance_id=absent_record.id,
        )

    if created:
        broadcast_attendance_update()
    return created


def get_lesson_attendance(db: Session, student_id: int, lesson_id: int, day: date) -> LessonAttendance | None:
    return db.query(LessonAttendance).filter(
        LessonAttendance.student_id == student_id,
        LessonAttendance.lesson_id == lesson_id,
        LessonAttendance.attendance_date == day,
    ).first()


def _status_for_lesson_detection(detected_at: datetime, lesson_start: time, grace_minutes: int = 10) -> str:
    start_min = lesson_start.hour * 60 + lesson_start.minute
    grace_min = start_min + grace_minutes
    grace_time = time(grace_min // 60 % 24, grace_min % 60)
    return PRESENT if detected_at.time() <= grace_time else LATE


def record_lesson_detection(
    db: Session,
    student_id: int,
    lesson_id: int,
    lesson_start: time,
    camera_id: int | None = None,
    confidence: float | None = 1.0,
    detected_at: datetime | None = None,
) -> LessonAttendance:
    detected_at = detected_at or datetime.now()
    today = detected_at.date()
    existing = get_lesson_attendance(db, student_id, lesson_id, today)
    if existing:
        if existing.status == ABSENT:
            existing.status = _status_for_lesson_detection(detected_at, lesson_start)
            existing.camera_id = camera_id or existing.camera_id
            existing.confidence = confidence if confidence is not None else existing.confidence
            existing.detected_at = detected_at
            db.commit()
            db.refresh(existing)
        return existing

    record = LessonAttendance(
        student_id=student_id,
        lesson_id=lesson_id,
        camera_id=camera_id,
        status=_status_for_lesson_detection(detected_at, lesson_start),
        confidence=confidence,
        attendance_date=today,
        detected_at=detected_at,
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return record


def mark_absent_for_lesson(
    db: Session,
    class_id: int,
    lesson_id: int,
    day: date | None = None,
) -> list[LessonAttendance]:
    day = day or date.today()
    created: list[LessonAttendance] = []

    students = db.query(Student).filter(
        Student.class_id == class_id,
        Student.is_active == True,
    ).all()

    for student in students:
        if get_lesson_attendance(db, student.id, lesson_id, day):
            continue
        record = LessonAttendance(
            student_id=student.id,
            lesson_id=lesson_id,
            status=ABSENT,
            attendance_date=day,
            detected_at=datetime.now(),
        )
        db.add(record)
        db.flush()
        created.append(record)

    if created:
        db.commit()
        for record in created:
            db.refresh(record)
    return created


def mark_absent_for_finished_lessons(db: Session) -> list[LessonAttendance]:
    today = date.today()
    created: list[LessonAttendance] = []

    for lesson in finished_lessons_today(db):
        students = db.query(Student).filter(
            Student.class_id == lesson.class_id,
            Student.is_active == True,
        ).all()
        for student in students:
            if get_lesson_attendance(db, student.id, lesson.id, today):
                continue
            record = LessonAttendance(
                student_id=student.id,
                lesson_id=lesson.id,
                status=ABSENT,
                attendance_date=today,
                detected_at=datetime.now(),
            )
            db.add(record)
            db.flush()
            created.append(record)

    if created:
        db.commit()
        for record in created:
            db.refresh(record)
    return created


def mark_left_school_students(
    db: Session,
    now: datetime | None = None,
    missing_after_minutes: int | None = None,
) -> list[Attendance]:
    now = now or datetime.now()
    missing_after_minutes = missing_after_minutes or settings.left_school_after_minutes
    threshold = now - timedelta(minutes=missing_after_minutes)

    from app.models.school_model import School

    group_mode_schools = [
        row[0] for row in db.query(School.id).filter(School.group_mode == True).all()
    ]

    query = db.query(Attendance).filter(
        Attendance.attendance_date == now.date(),
        Attendance.status.in_([PRESENT, LATE]),
        Attendance.last_seen != None,
        Attendance.last_seen < threshold,
    )
    if group_mode_schools:
        query = query.join(Student, Student.id == Attendance.student_id).filter(
            ~Student.school_id.in_(group_mode_schools)
        )
    records = query.all()

    updated = []
    for attendance in records:
        attendance.status = LEFT_SCHOOL
        attendance.time_out = attendance.last_seen
        attendance.updated_at = now
        student = db.query(Student).filter(Student.id == attendance.student_id).first()
        if student:
            create_notification_event(
                db,
                event_type=LEFT_SCHOOL,
                title="Фарзандатон рафт",
                body=f"Фарзандатон {student.first_name} {student.last_name} муддати тӯлонӣ дида нашуд.",
                parent_id=student.parent_id,
                student_id=student.id,
                attendance_id=attendance.id,
            )
        enqueue_attendance_event(db, attendance, operation="upsert")
        updated.append(attendance)

    db.commit()
    for attendance in updated:
        db.refresh(attendance)
    return updated


def attendance_history(
    db: Session,
    student_id: int | None = None,
    parent_ids: list[int] | None = None,
    school_id: int | None = None,
    limit: int = 100,
) -> list[Attendance]:
    query = db.query(Attendance)
    joined_student = False

    if parent_ids is not None:
        query = query.join(Student, Student.id == Attendance.student_id).filter(
            Student.parent_id.in_(parent_ids)
        )
        joined_student = True
    if school_id is not None:
        if not joined_student:
            query = query.join(Student, Student.id == Attendance.student_id)
        query = query.filter(Student.school_id == school_id)
    if student_id is not None:
        query = query.filter(Attendance.student_id == student_id)

    return query.order_by(
        Attendance.attendance_date.desc(),
        Attendance.id.desc(),
    ).limit(limit).all()


LESSON_NONE = "none"
LESSON_UPCOMING = "upcoming"
LESSON_RUNNING = "running"
LESSON_FINISHED = "finished"


def class_lesson_states(db: Session, now: datetime | None = None) -> dict[int, str]:
    now = now or datetime.now()
    weekday = now.weekday()
    minutes_now = now.hour * 60 + now.minute

    spans: dict[int, list[tuple[int, int]]] = {}
    for lesson in db.query(Lesson).filter(Lesson.day_of_week == weekday).all():
        try:
            hours, minutes = lesson.start_time.split(":")
            start = int(hours) * 60 + int(minutes)
        except (ValueError, AttributeError):
            continue
        spans.setdefault(lesson.class_id, []).append(
            (start, start + (lesson.duration_minutes or 45))
        )

    states: dict[int, str] = {}
    for class_id, windows in spans.items():
        if any(start <= minutes_now < end for start, end in windows):
            states[class_id] = LESSON_RUNNING
        elif any(minutes_now < start for start, _ in windows):
            states[class_id] = LESSON_UPCOMING
        else:
            states[class_id] = LESSON_FINISHED
    return states


def classes_in_session_now(db: Session, now: datetime | None = None) -> set[int]:
    now = now or datetime.now()
    weekday = now.weekday()
    minutes_now = now.hour * 60 + now.minute

    running: set[int] = set()
    for lesson in db.query(Lesson).filter(Lesson.day_of_week == weekday).all():
        try:
            hours, minutes = lesson.start_time.split(":")
            start = int(hours) * 60 + int(minutes)
        except (ValueError, AttributeError):
            continue
        end = start + (lesson.duration_minutes or 45)
        if start <= minutes_now < end:
            running.add(lesson.class_id)

    return running
