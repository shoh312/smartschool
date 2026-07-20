from datetime import date, datetime

from sqlalchemy import event
from sqlalchemy.orm import Session

from app.models.class_model import Class
from app.models.parent_model import Parent
from app.models.student import Student
from app.models.sync_outbox_model import SyncOutboxEntry
from app.realtime import wake_sync_worker


@event.listens_for(Session, "before_commit")
def _mark_pending_sync_wake(session: Session) -> None:
    # `session.new` is only populated up to the point the flush/commit
    # clears it, so this has to run in before_commit (not after_commit,
    # where it'd already be empty) -- stash the result on session.info to
    # read back once the commit has actually landed.
    if any(isinstance(obj, SyncOutboxEntry) for obj in session.new):
        session.info["_wake_sync_after_commit"] = True


@event.listens_for(Session, "after_commit")
def _wake_sync_worker_after_commit(session: Session) -> None:
    # Waking the drain loop only after the transaction that added the
    # SyncOutboxEntry has actually committed -- not at enqueue time, before
    # the caller's own db.commit() -- avoids a race where the loop wakes,
    # queries, finds nothing yet (row not durable/visible), and falls all
    # the way back to the POLL_INTERVAL_SECONDS timeout anyway, defeating
    # the point of waking it early at all.
    if session.info.pop("_wake_sync_after_commit", False):
        wake_sync_worker()


def _iso(value):
    if value is None:
        return None
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    return value


def _student_payload(student: Student, class_obj: "Class | None") -> dict:
    return {
        "local_id": student.id,
        "first_name": student.first_name,
        "last_name": student.last_name,
        "class_name": class_obj.name if class_obj else None,
        "local_class_id": student.class_id,
        "is_active": student.is_active,
    }


def _parent_payload(parent: Parent) -> dict:
    return {"phone": parent.phone, "full_name": parent.full_name}


def _resolve_parent_and_class(db: Session, student: Student):
    """Returns (parent, class_obj) or (None, None) if this student has no
    parent phone to sync to -- nothing for the Public Server to attach the
    event to, so callers should skip enqueueing entirely in that case.
    """
    if not student.parent_id:
        return None, None
    parent = db.query(Parent).filter(Parent.id == student.parent_id).first()
    if not parent or not parent.phone:
        return None, None
    class_obj = (
        db.query(Class).filter(Class.id == student.class_id).first()
        if student.class_id
        else None
    )
    return parent, class_obj


def _enqueue(db: Session, entity_type: str, entity_id: int, operation: str, payload: dict) -> None:
    # Add-only, no commit -- the caller's own db.commit() (right after this
    # call, alongside the source-of-truth write) is what makes this durable.
    # See SyncOutboxEntry's docstring for why that ordering matters. The
    # drain loop's wake-up is triggered by the after_commit session event
    # below (not here) -- see its comment for why it can't happen at
    # enqueue time.
    db.add(
        SyncOutboxEntry(
            entity_type=entity_type,
            entity_id=entity_id,
            operation=operation,
            payload=payload,
        )
    )


def enqueue_student_event(db: Session, student: Student, operation: str = "upsert") -> None:
    parent, class_obj = _resolve_parent_and_class(db, student)
    if not parent:
        return

    _enqueue(
        db,
        "student",
        student.id,
        operation,
        {
            "type": "student",
            "operation": operation,
            "parent": _parent_payload(parent),
            "student": _student_payload(student, class_obj),
        },
    )


def enqueue_grade_event(db: Session, grade, operation: str = "upsert") -> None:
    student = db.query(Student).filter(Student.id == grade.student_id).first()
    if not student:
        return
    parent, class_obj = _resolve_parent_and_class(db, student)
    if not parent:
        return

    _enqueue(
        db,
        "grade",
        grade.id,
        operation,
        {
            "type": "grade",
            "operation": operation,
            "parent": _parent_payload(parent),
            "student": _student_payload(student, class_obj),
            "grade": {
                "local_id": grade.id,
                "subject": grade.subject,
                "value": grade.value,
                "comment": grade.comment,
                "grade_date": _iso(grade.grade_date),
                "teacher_name": grade.teacher_name,
                "local_teacher_id": grade.teacher_id,
            },
        },
    )


def enqueue_attendance_event(db: Session, attendance, operation: str = "upsert") -> None:
    student = db.query(Student).filter(Student.id == attendance.student_id).first()
    if not student:
        return
    parent, class_obj = _resolve_parent_and_class(db, student)
    if not parent:
        return

    _enqueue(
        db,
        "attendance",
        attendance.id,
        operation,
        {
            "type": "attendance",
            "operation": operation,
            "parent": _parent_payload(parent),
            "student": _student_payload(student, class_obj),
            "attendance": {
                "local_id": attendance.id,
                "status": attendance.status,
                "attendance_date": _iso(attendance.attendance_date),
                "time_in": _iso(attendance.time_in),
                "time_out": _iso(attendance.time_out),
                "last_seen": _iso(attendance.last_seen),
            },
        },
    )
