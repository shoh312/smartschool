from sqlalchemy.orm import Session

from app.models.attendance_model import AttendanceStatus
from app.models.grade_model import Grade
from app.models.notification_model import NotificationEvent
from app.models.parent_model import Parent
from app.models.school_model import School
from app.models.student_model import Student
from app.notifications.firebase import create_and_send_notification
from app.schemas.sync_schema import SyncEvent
from app.utils.phone import normalize_phone

ATTENDANCE_EVENT_TITLES = {
    "present": ("Farzandingiz maktabga keldi", "keldi"),
    "late": ("Farzandingiz kechikib keldi", "kechikib keldi"),
    "absent": ("Farzandingiz maktabga kelmadi", "kelmadi"),
    "left_school": ("Farzandingiz maktabdan chiqib ketdi", "chiqib ketdi"),
}


def _upsert_parent(db: Session, phone: str, full_name: str | None) -> Parent:
    normalized = normalize_phone(phone)
    parent = db.query(Parent).filter(Parent.phone == normalized).first()
    if parent:
        if full_name and parent.full_name != full_name:
            parent.full_name = full_name
        return parent

    parent = Parent(phone=normalized, full_name=full_name or normalized)
    db.add(parent)
    db.flush()
    return parent


def _upsert_student(db: Session, school: School, event, parent: Parent) -> Student:
    student = db.query(Student).filter(
        Student.school_id == school.id,
        Student.local_student_id == event.student.local_id,
    ).first()

    if not student:
        student = Student(
            school_id=school.id,
            local_student_id=event.student.local_id,
            parent_id=parent.id,
        )
        db.add(student)

    student.first_name = event.student.first_name
    student.last_name = event.student.last_name
    student.class_name = event.student.class_name
    student.local_class_id = event.student.local_class_id
    student.parent_id = parent.id
    student.is_active = event.student.is_active
    if event.type == "student" and event.operation == "deactivate":
        student.is_active = False

    db.flush()
    return student


def apply_sync_event(db: Session, school: School, event: SyncEvent) -> None:
    parent = _upsert_parent(db, event.parent.phone, event.parent.full_name)
    student = _upsert_student(db, school, event, parent)

    if event.type == "grade" and event.grade is not None:
        _apply_grade(db, school, student, event)
    elif event.type == "attendance" and event.attendance is not None:
        _apply_attendance(db, school, student, event)

    db.commit()


def _apply_grade(db: Session, school: School, student: Student, event: SyncEvent) -> None:
    grade = db.query(Grade).filter(
        Grade.school_id == school.id,
        Grade.local_grade_id == event.grade.local_id,
    ).first()

    if event.operation == "delete":
        if grade:
            db.delete(grade)
        return

    if not grade:
        grade = Grade(school_id=school.id, local_grade_id=event.grade.local_id)
        db.add(grade)

    grade.student_id = student.id
    grade.subject = event.grade.subject
    grade.value = event.grade.value
    grade.comment = event.grade.comment
    grade.grade_date = event.grade.grade_date
    grade.teacher_name = event.grade.teacher_name
    grade.local_class_id = event.student.local_class_id or 0
    grade.local_teacher_id = event.grade.local_teacher_id


def _apply_attendance(db: Session, school: School, student: Student, event: SyncEvent) -> None:
    attendance = db.query(AttendanceStatus).filter(
        AttendanceStatus.school_id == school.id,
        AttendanceStatus.local_attendance_id == event.attendance.local_id,
    ).first()

    previous_status = attendance.status if attendance else None
    is_new = attendance is None

    if not attendance:
        attendance = AttendanceStatus(
            school_id=school.id, local_attendance_id=event.attendance.local_id
        )
        db.add(attendance)

    attendance.student_id = student.id
    attendance.status = event.attendance.status
    attendance.attendance_date = event.attendance.attendance_date
    attendance.time_in = event.attendance.time_in
    attendance.time_out = event.attendance.time_out
    attendance.last_seen = event.attendance.last_seen

    # Only notify on an actual status change (new row, or status differs from
    # what's already stored) -- an idempotent retry of the same event must
    # re-apply the same status without re-notifying the parent every time.
    status_changed = is_new or previous_status != attendance.status
    if status_changed and attendance.status in ATTENDANCE_EVENT_TITLES:
        title, verb = ATTENDANCE_EVENT_TITLES[attendance.status]
        student_name = f"{student.first_name} {student.last_name}".strip()
        db.flush()
        event_row = NotificationEvent(
            parent_id=student.parent_id,
            student_id=student.id,
            school_id=school.id,
            event_type=f"attendance_{attendance.status}",
            title=title,
            body=f"{student_name} bugun maktabga {verb}.",
        )
        db.add(event_row)
        db.flush()
        create_and_send_notification(db, event_row)
