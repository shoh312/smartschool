"""Telling pupils about work: once when it arrives, once before it's due.

Both notifications go to the pupil's own device rather than their parent's.
That's the point of them -- a reminder that lands on the phone the homework
will actually be done on.

Sent from this server because it is the only one the pupil's phone can
reach, and because it already knows who has submitted and who hasn't.
"""

from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from app.models.material_model import Material, MaterialAssignment, MaterialAttempt
from app.models.notification_model import NotificationEvent
from app.models.student_model import Student
from app.notifications.firebase import create_and_send_notification

# How long before the deadline the "you haven't done this" nudge goes out.
REMINDER_LEAD = timedelta(days=1)

EVENT_NEW = "material_assigned"
EVENT_DUE = "material_due_soon"


def _students_in_class(db: Session, assignment: MaterialAssignment) -> list[Student]:
    return (
        db.query(Student)
        .filter(
            Student.school_id == assignment.school_id,
            Student.local_class_id == assignment.local_class_id,
            Student.is_active == True,  # noqa: E712 -- SQLAlchemy column comparison
        )
        .all()
    )


def _already_sent(db: Session, event_type: str, student_id: int, assignment_id: int) -> bool:
    """Guard against repeats.

    The published event is re-sent by the school server whenever a teacher
    edits the deadline, and the reminder loop runs every hour -- without
    this, a pupil's phone would buzz on every pass.
    """
    return (
        db.query(NotificationEvent)
        .filter(
            NotificationEvent.event_type == event_type,
            NotificationEvent.student_id == student_id,
            NotificationEvent.body.like(f"%#{assignment_id}%"),
        )
        .first()
        is not None
    )


def _send(
    db: Session,
    student: Student,
    assignment: MaterialAssignment,
    event_type: str,
    title: str,
    body: str,
) -> None:
    event = NotificationEvent(
        # No parent_id: this is the pupil's own reminder. Both ids exist on
        # the model, and firebase.create_and_send_notification picks the
        # device list from whichever is set.
        student_id=student.id,
        school_id=assignment.school_id,
        event_type=event_type,
        title=title,
        # The assignment id is carried in the text so _already_sent can
        # recognise this exact reminder later without a new column.
        body=f"{body} #{assignment.id}",
    )
    db.add(event)
    db.commit()
    create_and_send_notification(db, event)


def notify_assignment_published(db: Session, assignment: MaterialAssignment) -> int:
    """One message per pupil in the class when work is handed out."""
    if assignment.published_at is None:
        return 0

    material = (
        db.query(Material)
        .filter(
            Material.school_id == assignment.school_id,
            Material.local_material_id == assignment.local_material_id,
        )
        .first()
    )
    if material is None:
        # The material's own sync event hasn't landed yet. Skipping is safe:
        # the assignment event is re-sent whenever the teacher touches it,
        # and the pupil sees the work in their list either way.
        return 0

    sent = 0
    for student in _students_in_class(db, assignment):
        if _already_sent(db, EVENT_NEW, student.id, assignment.id):
            continue
        _send(
            db,
            student,
            assignment,
            EVENT_NEW,
            "Янги супориш",
            f"{material.subject}: {material.title}",
        )
        sent += 1
    return sent


def send_due_reminders(db: Session, now: datetime | None = None) -> int:
    """Nudge pupils who still haven't submitted, a day before the deadline.

    Deliberately only for those who haven't finished: a pupil who did the
    work on the first evening should not be chased about it.
    """
    now = now or datetime.utcnow()
    window_end = now + REMINDER_LEAD

    assignments = (
        db.query(MaterialAssignment)
        .filter(
            MaterialAssignment.published_at.isnot(None),
            MaterialAssignment.due_at.isnot(None),
            MaterialAssignment.due_at > now,
            MaterialAssignment.due_at <= window_end,
        )
        .all()
    )

    sent = 0
    for assignment in assignments:
        material = (
            db.query(Material)
            .filter(
                Material.school_id == assignment.school_id,
                Material.local_material_id == assignment.local_material_id,
            )
            .first()
        )
        if material is None:
            continue

        submitted = {
            row[0]
            for row in db.query(MaterialAttempt.student_id)
            .filter(
                MaterialAttempt.assignment_id == assignment.id,
                MaterialAttempt.submitted_at.isnot(None),
            )
            .distinct()
            .all()
        }

        for student in _students_in_class(db, assignment):
            if student.id in submitted:
                continue
            if _already_sent(db, EVENT_DUE, student.id, assignment.id):
                continue
            _send(
                db,
                student,
                assignment,
                EVENT_DUE,
                "Мӯҳлат наздик аст",
                f"{material.title} — ҳанӯз иҷро накардаед",
            )
            sent += 1
    return sent
