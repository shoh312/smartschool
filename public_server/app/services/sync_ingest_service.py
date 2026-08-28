from datetime import datetime

from sqlalchemy.orm import Session

from app.models.announcement_model import Announcement
from app.models.attendance_model import AttendanceStatus
from app.models.calendar_event_model import CalendarEvent
from app.models.diary_model import DiaryEntry
from app.models.grade_model import Grade
from app.models.material_model import Material, MaterialAssignment, MaterialBlock
from app.models.notification_model import NotificationEvent
from app.models.parent_model import Parent
from app.models.school_model import School
from app.models.student_analytics_model import StudentAnalytics
from app.models.student_model import Student
from app.notifications.firebase import create_and_send_notification
from app.services.material_notification_service import notify_assignment_published
from app.schemas.sync_schema import SyncEvent
from app.utils.phone import normalize_phone

# Tajik: this is the one message a parent actually receives, and it should
# arrive in the language the rest of their app is in.
#
# The time matters as much as the fact. "Your child came to school" leaves a
# parent wondering when; "came at 08:12" is the whole answer, and for a late
# arrival it is the difference between a shrug and a conversation.
#
# `absent` carries no time on purpose -- the child was never seen, so any
# clock reading would be the moment the system gave up, not anything about
# the child.
ATTENDANCE_MESSAGES = {
    "present": {
        "title": "Фарзандатон ба мактаб омад",
        "timed": "{name} соати {time} ба мактаб омад.",
        "plain": "{name} имрӯз ба мактаб омад.",
        "field": "time_in",
    },
    "late": {
        "title": "Фарзандатон дер омад",
        "timed": "{name} соати {time} дер омад.",
        "plain": "{name} имрӯз дер омад.",
        "field": "time_in",
    },
    "absent": {
        "title": "Фарзандатон ба мактаб наомад",
        "timed": "{name} имрӯз ба мактаб наомад.",
        "plain": "{name} имрӯз ба мактаб наомад.",
        "field": None,
    },
    "left_school": {
        "title": "Фарзандатон аз мактаб рафт",
        "timed": "{name} соати {time} аз мактаб рафт.",
        "plain": "{name} аз мактаб рафт.",
        "field": "last_seen",
    },
}


def _clock(value) -> str | None:
    """`HH:MM` from whatever the sync delivered, or None if it is unusable.

    Times arrive as the school's own local clock -- the school server writes
    `datetime.now()` and the sync passes it through untouched -- so they are
    printed as they are, with no timezone maths that would shift a parent's
    notification by hours.
    """
    if value is None:
        return None
    if isinstance(value, str):
        try:
            value = datetime.fromisoformat(value)
        except ValueError:
            return None
    try:
        return value.strftime("%H:%M")
    except (AttributeError, ValueError):
        return None


def _attendance_message(status: str, student_name: str, attendance) -> tuple[str, str] | None:
    template = ATTENDANCE_MESSAGES.get(status)
    if template is None:
        return None

    clock = None
    if template["field"]:
        clock = _clock(getattr(attendance, template["field"], None))

    body = (template["timed"] if clock else template["plain"]).format(
        name=student_name, time=clock
    )
    return template["title"], body


def _upsert_parent(
    db: Session,
    phone: str,
    full_name: str | None,
    password_hash: str | None = None,
    password_salt: str | None = None,
) -> Parent:
    normalized = normalize_phone(phone)
    parent = db.query(Parent).filter(Parent.phone == normalized).first()
    if parent:
        if full_name and parent.full_name != full_name:
            parent.full_name = full_name
        # Only ever fills a gap, never overwrites. The school issues a
        # password once, but a parent can change it here afterwards, and the
        # school's copy of the old hash arrives again with every grade and
        # every absence -- writing it back would undo their change on the
        # next mark their child got.
        if password_hash and not parent.password_hash:
            parent.password_hash = password_hash
            parent.password_salt = password_salt
        return parent

    parent = Parent(
        phone=normalized,
        full_name=full_name or normalized,
        password_hash=password_hash,
        password_salt=password_salt,
    )
    db.add(parent)
    db.flush()

    # No SMS from here any more. Registering is something the parent starts
    # themselves, from the Register button on the sign-in screen, and a code
    # they did not ask for arriving alongside one they did was half of what
    # made the sign-in confusing. scripts/invite_parents.py still exists for
    # the families who were registered before any of this and need a nudge.
    return parent


def _upsert_student(db: Session, school: School, event, parent: Parent | None) -> Student:
    student = db.query(Student).filter(
        Student.school_id == school.id,
        Student.local_student_id == event.student.local_id,
    ).first()

    if not student:
        student = Student(
            school_id=school.id,
            local_student_id=event.student.local_id,
            parent_id=parent.id if parent else None,
        )
        db.add(student)

    student.first_name = event.student.first_name
    student.last_name = event.student.last_name
    student.class_name = event.student.class_name
    student.local_class_id = event.student.local_class_id
    # Only when one was sent: a later parentless event must not unlink a
    # pupil from the parent an earlier one established.
    if parent is not None:
        student.parent_id = parent.id
    student.is_active = event.student.is_active
    if event.student.username is not None:
        student.username = event.student.username
    if event.student.password_hash is not None:
        student.password_hash = event.student.password_hash
        student.password_salt = event.student.password_salt
    if event.type == "student" and event.operation == "deactivate":
        student.is_active = False

    db.flush()
    return student


def apply_sync_event(db: Session, school: School, event: SyncEvent) -> None:
    # Materials belong to a class, not a family, and arrive without a
    # parent/student block -- handled before the identity upsert, which has
    # nothing to work with for them.
    if event.type == "material" and event.material is not None:
        _apply_material(db, school, event)
        db.commit()
        return
    if event.type == "material_assignment" and event.material_assignment is not None:
        assignment = _apply_material_assignment(db, school, event)
        db.commit()
        if assignment is not None:
            # After the commit: the pupils' list has to be able to show the
            # work by the time their phone buzzes about it.
            notify_assignment_published(db, assignment)
        return

    parent = (
        _upsert_parent(
            db,
            event.parent.phone,
            event.parent.full_name,
            event.parent.password_hash,
            event.parent.password_salt,
        )
        if event.parent is not None
        else None
    )
    student = _upsert_student(db, school, event, parent)

    if event.type == "grade" and event.grade is not None:
        _apply_grade(db, school, student, event)
    elif event.type == "attendance" and event.attendance is not None:
        _apply_attendance(db, school, student, event)
    elif event.type == "student_analytics" and event.student_analytics is not None:
        _apply_student_analytics(db, school, student, event)
    elif event.type == "diary" and event.diary is not None:
        _apply_diary(db, school, event)
    elif event.type == "calendar_event" and event.calendar_event is not None:
        _apply_calendar_event(db, school, event)
    elif event.type == "announcement" and event.announcement is not None:
        _apply_announcement(db, school, student, event)

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
    grade.quarter = event.grade.quarter
    grade.value = event.grade.value
    grade.comment = event.grade.comment
    grade.grade_date = event.grade.grade_date
    grade.teacher_name = event.grade.teacher_name
    grade.local_class_id = event.student.local_class_id or 0
    grade.local_teacher_id = event.grade.local_teacher_id


def _apply_student_analytics(db: Session, school: School, student: Student, event: SyncEvent) -> None:
    data = event.student_analytics
    analytics = db.query(StudentAnalytics).filter(
        StudentAnalytics.student_id == student.id,
        StudentAnalytics.quarter == data.quarter,
        StudentAnalytics.school_year == data.school_year,
    ).first()

    if not analytics:
        analytics = StudentAnalytics(
            school_id=school.id,
            student_id=student.id,
            quarter=data.quarter,
            school_year=data.school_year,
        )
        db.add(analytics)

    analytics.overall_average = data.overall_average
    analytics.class_rank_position = data.class_rank_position
    analytics.class_rank_out_of = data.class_rank_out_of
    analytics.parallel_rank_position = data.parallel_rank_position
    analytics.parallel_rank_out_of = data.parallel_rank_out_of
    analytics.school_rank_position = data.school_rank_position
    analytics.school_rank_out_of = data.school_rank_out_of
    analytics.class_average = data.class_average
    analytics.parallel_average = data.parallel_average
    analytics.school_average = data.school_average
    analytics.subject_breakdown = [item.model_dump() for item in data.subject_breakdown]
    analytics.strongest_subject = data.strongest_subject
    analytics.weakest_subject = data.weakest_subject
    analytics.lesson_attendance_rate = data.lesson_attendance_rate
    analytics.trend = [item.model_dump() for item in data.trend]


def _apply_diary(db: Session, school: School, event: SyncEvent) -> None:
    data = event.diary
    entry = db.query(DiaryEntry).filter(
        DiaryEntry.school_id == school.id,
        DiaryEntry.local_lesson_id == data.local_lesson_id,
        DiaryEntry.log_date == data.log_date,
    ).first()

    if not entry:
        entry = DiaryEntry(
            school_id=school.id,
            local_lesson_id=data.local_lesson_id,
            local_class_id=event.student.local_class_id or 0,
            log_date=data.log_date,
            subject=data.subject,
            day_of_week=data.day_of_week,
            start_time=data.start_time,
            duration_minutes=data.duration_minutes,
        )
        db.add(entry)

    entry.local_class_id = event.student.local_class_id or entry.local_class_id
    entry.subject = data.subject
    entry.room = data.room
    entry.teacher_name = data.teacher_name
    entry.day_of_week = data.day_of_week
    entry.start_time = data.start_time
    entry.duration_minutes = data.duration_minutes
    entry.homework = data.homework
    entry.teacher_comment = data.teacher_comment


def _apply_calendar_event(db: Session, school: School, event: SyncEvent) -> None:
    data = event.calendar_event
    calendar_event = db.query(CalendarEvent).filter(
        CalendarEvent.school_id == school.id,
        CalendarEvent.local_event_id == data.local_id,
    ).first()

    if event.operation == "delete":
        if calendar_event:
            db.delete(calendar_event)
        return

    if not calendar_event:
        calendar_event = CalendarEvent(school_id=school.id, local_event_id=data.local_id)
        db.add(calendar_event)

    calendar_event.local_class_id = data.local_class_id
    calendar_event.title = data.title
    calendar_event.description = data.description
    calendar_event.event_type = data.event_type
    calendar_event.start_date = data.start_date
    calendar_event.end_date = data.end_date


def _apply_announcement(db: Session, school: School, student: Student, event: SyncEvent) -> None:
    data = event.announcement
    announcement = db.query(Announcement).filter(
        Announcement.school_id == school.id,
        Announcement.local_announcement_id == data.local_id,
    ).first()

    if event.operation == "delete":
        if announcement:
            db.delete(announcement)
        return

    if not announcement:
        announcement = Announcement(school_id=school.id, local_announcement_id=data.local_id)
        db.add(announcement)

    announcement.local_class_id = data.local_class_id
    announcement.title = data.title
    announcement.body = data.body
    announcement.created_at_local = data.created_at

    # The local server fans this same announcement out once per affected
    # student (see enqueue_announcement_event), but the Announcement row
    # itself is deduped to one shared row above -- so "is this row new"
    # can't gate the notification (only the very first of N students would
    # ever be notified). Instead, dedupe per PARENT: skip only if this exact
    # parent has already been notified for this exact announcement (an
    # idempotent retry), so every distinct parent still gets notified once.
    if student.parent_id:
        already_notified = db.query(NotificationEvent).filter(
            NotificationEvent.parent_id == student.parent_id,
            NotificationEvent.event_type == "announcement",
            NotificationEvent.title == announcement.title,
            NotificationEvent.body == announcement.body,
        ).first()
        if not already_notified:
            event_row = NotificationEvent(
                parent_id=student.parent_id,
                student_id=student.id,
                school_id=school.id,
                event_type="announcement",
                title=announcement.title,
                body=announcement.body,
            )
            db.add(event_row)
            db.flush()
            create_and_send_notification(db, event_row)


def _apply_attendance(db: Session, school: School, student: Student, event: SyncEvent) -> None:
    attendance = db.query(AttendanceStatus).filter(
        AttendanceStatus.school_id == school.id,
        AttendanceStatus.local_attendance_id == event.attendance.local_id,
    ).first()

    # A record the school has withdrawn -- an absence marked on a day that
    # turned out to have no lessons, say. Nothing to notify: the parent was
    # already told, and the correction is the row going away.
    if event.operation == "delete":
        if attendance:
            db.delete(attendance)
        return

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
    message = (
        _attendance_message(
            attendance.status,
            f"{student.first_name} {student.last_name}".strip(),
            attendance,
        )
        if status_changed
        else None
    )
    if message is not None:
        title, body = message
        db.flush()
        event_row = NotificationEvent(
            parent_id=student.parent_id,
            student_id=student.id,
            school_id=school.id,
            event_type=f"attendance_{attendance.status}",
            title=title,
            body=body,
        )
        db.add(event_row)
        db.flush()
        create_and_send_notification(db, event_row)


def _apply_material(db: Session, school: School, event: SyncEvent) -> None:
    """Mirror a material and its blocks, keyed by the school server's ids.

    Blocks are replaced wholesale rather than diffed: the local server
    already refuses to edit the questions of a material that has been handed
    out, so a changed block list only ever arrives for something nobody has
    started answering yet.
    """
    data = event.material
    material = db.query(Material).filter(
        Material.school_id == school.id,
        Material.local_material_id == data.local_id,
    ).first()

    if event.operation == "delete":
        if material:
            db.delete(material)
        return

    if not material:
        material = Material(school_id=school.id, local_material_id=data.local_id)
        db.add(material)

    material.subject = data.subject
    material.title = data.title
    material.description = data.description
    material.teacher_name = data.teacher_name
    material.max_score = data.max_score
    db.flush()

    for existing in db.query(MaterialBlock).filter(
        MaterialBlock.material_id == material.id
    ).all():
        db.delete(existing)
    db.flush()

    for block in data.blocks:
        db.add(
            MaterialBlock(
                material_id=material.id,
                local_block_id=block.local_id,
                position=block.position,
                block_type=block.block_type,
                body=block.body or "",
                question_type=block.question_type,
                options=block.options,
                correct=block.correct,
                points=block.points,
            )
        )


def _apply_material_assignment(db: Session, school: School, event: SyncEvent) -> MaterialAssignment | None:
    data = event.material_assignment
    assignment = db.query(MaterialAssignment).filter(
        MaterialAssignment.school_id == school.id,
        MaterialAssignment.local_assignment_id == data.local_id,
    ).first()

    if event.operation == "delete":
        if assignment:
            db.delete(assignment)
        return None

    if not assignment:
        assignment = MaterialAssignment(
            school_id=school.id,
            local_assignment_id=data.local_id,
        )
        db.add(assignment)

    assignment.local_material_id = data.local_material_id
    assignment.local_class_id = data.local_class_id
    assignment.class_name = data.class_name
    assignment.teacher_name = data.teacher_name
    assignment.mode = data.mode
    assignment.due_at = data.due_at
    assignment.max_attempts = data.max_attempts
    assignment.published_at = data.published_at
    return assignment
