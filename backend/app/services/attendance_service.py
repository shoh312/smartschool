from datetime import date, datetime, time, timedelta

from sqlalchemy.orm import Session

from app.models.attendance_model import Attendance
from app.models.student import Student
from app.notifications.firebase import create_notification_event
from app.realtime import broadcast_attendance_update
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
    if not cam or not cam.class_id:
        return None
    school_class = db.query(Class).filter(Class.id == cam.class_id).first()
    if school_class and school_class.start_time:
        try:
            parts = school_class.start_time.split(':')
            return time(int(parts[0]), int(parts[1]))
        except (ValueError, IndexError):
            pass
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

    active_students = db.query(Student).filter(Student.is_active == True).all()
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


def mark_left_school_students(
    db: Session,
    now: datetime | None = None,
    missing_after_minutes: int | None = None,
) -> list[Attendance]:
    now = now or datetime.now()
    missing_after_minutes = missing_after_minutes or settings.left_school_after_minutes
    threshold = now - timedelta(minutes=missing_after_minutes)

    records = db.query(Attendance).filter(
        Attendance.attendance_date == now.date(),
        Attendance.status.in_([PRESENT, LATE]),
        Attendance.last_seen != None,
        Attendance.last_seen < threshold,
    ).all()

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
