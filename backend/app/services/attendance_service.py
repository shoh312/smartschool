from datetime import date, datetime, time, timedelta

from sqlalchemy.orm import Session

from app.models.attendance_model import Attendance
from app.models.lesson_attendance_model import LessonAttendance
from app.models.camera_position_model import CameraPosition
from app.models.lesson_model import Lesson
from app.models.student import Student
from app.notifications.firebase import create_notification_event
from app.realtime import broadcast_attendance_update
from app.services.camera_position_service import Slot, classes_with_started_slot
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
    """The hour the people this camera watches were due to arrive.

    Falling back to the school's morning cutoff when this returns None is
    right for a school and badly wrong for an academy. A camera bolted to a
    room carries no class of its own, so every group it saw came back None,
    and a pupil recognised at 14:04 for a lesson that began at 14:00 was
    written down as late against an 08:15 cutoff -- present in the lesson's
    own register, late on the day's, and red in the analytics either way.

    So a room camera is asked the only question that makes sense for it:
    which group is in front of it right now, and when was that group due.
    """
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
    """Start time of the timetable slot this room camera is inside."""
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
            
            # Send notification when they return or arrive late after being marked absent
            student = db.query(Student).filter(Student.id == student_id).first()
            if student:
                create_notification_event(
                    db,
                    event_type=attendance.status,
                    title="Student arrived",
                    body=f"{student.first_name} {student.last_name} has arrived at school.",
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

    # Send notification for the first arrival of the day
    student = db.query(Student).filter(Student.id == student_id).first()
    if student:
        create_notification_event(
            db,
            event_type=attendance.status,
            title="Student arrived",
            body=f"{student.first_name} {student.last_name} has arrived at school.",
            parent_id=student.parent_id,
            student_id=student.id,
            attendance_id=attendance.id,
        )

    broadcast_attendance_update()
    return attendance


def classes_in_session_on(lessons, weekday: int, clock: str | None = None) -> set[int]:
    """Which classes are expected in by `clock` on this weekday.

    A timetable slot is the only evidence the app has that a class was
    expected to be somewhere. Without this the day-level absence job marked
    every active pupil absent every single day after the cutoff -- Sundays,
    holidays, and classes whose timetable the school has not entered yet --
    which is how the database ended up with 842 absences against 1 present,
    56 of them on a Sunday.

    `clock` is what makes it "by now" rather than "at some point today", and
    it matters for an academy: a group whose lesson starts at 14:00 was being
    reported absent from 08:15, because having a lesson *somewhere* in the
    day was taken as being late for it. A school never noticed -- its first
    lesson starts before the cutoff -- but an afternoon group is not late at
    breakfast.
    """
    return {
        lesson.class_id
        for lesson in lessons
        if lesson.day_of_week == weekday
        and (clock is None or (lesson.start_time or "00:00") <= clock)
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

    # No lesson on the books means no school to be absent from. The
    # per-lesson job next door has always worked this way (it iterates
    # finished_lessons_today); this one did not, and that was the bug.
    clock = now.strftime("%H:%M") if day == now.date() else "23:59"
    in_session = classes_in_session_on(db.query(Lesson).all(), day.weekday(), clock)

    # An academy keeps no lesson timetable -- its schedule is the camera's
    # own list of groups, and without this every group would be exempt from
    # absence marking forever, silently. A group counts once its slot has
    # started: before that there is nothing to be late for.
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

    active_students = db.query(Student).filter(
        Student.is_active == True,  # noqa: E712
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
            title="Student absent",
            body=f"{student.first_name} {student.last_name} was not detected before 08:15.",
            parent_id=student.parent_id,
            student_id=student.id,
            attendance_id=absent_record.id,
        )

    return created


class DetectionCycleCounter:
    """Counts a camera's completed detect windows, per day.

    Exists as its own object because the interesting case is the one that is
    easy to get wrong in an inline counter: a camera thread runs for days,
    and a count carried over from yesterday would mark a whole class absent
    on the very first sweep of the morning -- before anybody has walked in.
    Rolling the count over at the date boundary is the whole job, and it is
    worth being able to test without a camera or a database.
    """

    def __init__(self, threshold: int, today: date | None = None):
        self.threshold = threshold
        self._day = today or date.today()
        self._count = 0

    @property
    def count(self) -> int:
        return self._count

    def record(self, day: date | None = None) -> bool:
        """Records one completed window; True once enough have run today."""
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
    """Marks a class's still-unseen students absent, once the camera has had
    more than one go at finding them.

    [mark_absent_students] answers the same question by the clock: anyone not
    seen by 08:15 is absent. That misfires whenever the camera's own schedule
    and the clock disagree -- a class starting late, a camera that reconnected
    slowly, a school day shifted for an event -- and it marks a child absent
    who nobody ever actually looked for.

    Counting the camera's passes instead ties the verdict to the evidence:
    the first pass can miss somebody who was turned away or walking in, so it
    only says "not found yet". By the second pass the room has been looked at
    twice, and a student still missing is genuinely not there.

    The caller owns the counting -- this runs only when it has already
    happened at least twice today (see live_detection.py).
    """
    now = datetime.now()
    day = day or now.date()

    students = db.query(Student).filter(
        Student.class_id == class_id,
        Student.is_active == True,  # noqa: E712
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
            title="Student absent",
            body=f"{student.first_name} {student.last_name} was not found in class today.",
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
    """Per-lesson counterpart to `record_detection` -- upserts one row per
    (student, lesson, day) so a student's presence can be judged per subject
    instead of only once for the whole day. Called alongside `record_detection`,
    never instead of it, so the existing day-level screens are unaffected.
    """
    detected_at = detected_at or datetime.now()
    today = detected_at.date()
    existing = get_lesson_attendance(db, student_id, lesson_id, today)
    if existing:
        # A pupil marked absent two sweeps into the lesson and then seen at
        # minute ten did turn up, and the register has to say so. Without
        # this the early marking would be a one-way door: the day-level
        # record_detection has always corrected itself this way, and the
        # per-lesson one did not, which is only safe while nothing marks a
        # lesson absent before it ends.
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
    """Marks absent, in the lesson that is running right now, every active
    pupil in the class the camera has not seen during it.

    Called from the detection loop once the room has been swept twice (see
    ABSENT_AFTER_CYCLES), rather than waiting for the bell like
    `mark_absent_for_finished_lessons` does. The point is the subject
    register: a teacher wants to see who is missing from *this* lesson while
    it is still running, not after it.

    Safe to call on every sweep afterwards -- it skips anyone who already has
    a row -- and safe to be wrong, because `record_lesson_detection` upgrades
    an absence back to present the moment the pupil is seen.
    """
    day = day or date.today()
    created: list[LessonAttendance] = []

    students = db.query(Student).filter(
        Student.class_id == class_id,
        Student.is_active == True,  # noqa: E712
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
    """For every lesson that has already ended today, mark absent any active
    student in that class with no LessonAttendance row yet. Naturally
    idempotent (skips students who already have a row), so this can run on
    every background-loop tick with no separate "already processed" state --
    unlike the day-level `mark_absent_students`, no notification is sent here
    per lesson (a student absent all day would otherwise get one notification
    per period).
    """
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

    # Group-mode schools are left out of this entirely.
    #
    # "Not seen for half an hour" means a child has left the building when a
    # camera watches its class continuously. It means nothing at all when the
    # camera looks at the room for ten seconds once every twenty minutes:
    # missing three of those looks is what sitting behind a classmate looks
    # like, and the register would quietly turn a pupil who is present into
    # one who went home -- changing the analytics block the roll call had
    # already settled, and telling their parent they left.
    #
    # The roll call decides who came; after it, only being seen may change a
    # record, and only upwards.
    from app.models.school_model import School

    group_mode_schools = [
        row[0] for row in db.query(School.id).filter(School.group_mode == True).all()  # noqa: E712
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
                title="Student left school",
                body=f"{student.first_name} {student.last_name} has not been seen for a long time.",
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
