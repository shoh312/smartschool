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
        "username": student.username,
        "password_hash": student.password_hash,
        "password_salt": student.password_salt,
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
    """Send a pupil's own record across.

    Used to return early when the pupil had no parent phone -- which
    silently stranded every such pupil on the school server, login and all,
    so they could sign in on the school's network and nowhere else. A pupil
    exists whether or not the school wrote down a parent's number.
    """
    parent, class_obj = _resolve_parent_and_class(db, student)
    if parent is None:
        class_obj = (
            db.query(Class).filter(Class.id == student.class_id).first()
            if student.class_id
            else None
        )

    _enqueue(
        db,
        "student",
        student.id,
        operation,
        {
            "type": "student",
            "operation": operation,
            **({"parent": _parent_payload(parent)} if parent else {}),
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
                "quarter": grade.quarter,
            },
        },
    )


def enqueue_student_analytics_event(db: Session, student: Student, overview: dict) -> None:
    """Pushes a pre-computed ranking/analytics snapshot (see
    analytics_service.build_student_overview) to the Public Server. Ranking
    needs the whole class/parallel/school roster, which the Public Server
    never has a full copy of (it only ever receives one child's own data per
    sync event) -- so unlike grades/attendance, this can't be recomputed
    there from synced rows. The local server computes it and pushes the
    finished numbers instead, same as every other synced entity.
    """
    parent, class_obj = _resolve_parent_and_class(db, student)
    if not parent:
        return

    _enqueue(
        db,
        "student_analytics",
        student.id,
        "upsert",
        {
            "type": "student_analytics",
            "operation": "upsert",
            "parent": _parent_payload(parent),
            "student": _student_payload(student, class_obj),
            "student_analytics": {
                "quarter": overview["quarter"],
                "school_year": overview["school_year"],
                "overall_average": overview["overall_average"],
                "class_rank_position": overview["class_rank"]["position"],
                "class_rank_out_of": overview["class_rank"]["out_of"],
                "parallel_rank_position": overview["parallel_rank"]["position"],
                "parallel_rank_out_of": overview["parallel_rank"]["out_of"],
                "school_rank_position": overview["school_rank"]["position"],
                "school_rank_out_of": overview["school_rank"]["out_of"],
                "class_average": overview["class_average"],
                "parallel_average": overview["parallel_average"],
                "school_average": overview["school_average"],
                "subject_breakdown": overview["subject_breakdown"],
                "strongest_subject": overview["strongest_subject"],
                "weakest_subject": overview["weakest_subject"],
                "lesson_attendance_rate": overview["lesson_attendance_rate"],
                "trend": overview["trend"],
            },
        },
    )


def _students_for_class(db: Session, class_id: int) -> list[Student]:
    return db.query(Student).filter(Student.class_id == class_id, Student.is_active == True).all()


def _students_for_school_or_class(db: Session, school_id: int | None, class_id: int | None) -> list[Student]:
    query = db.query(Student).filter(Student.is_active == True)
    if class_id is not None:
        query = query.filter(Student.class_id == class_id)
    else:
        query = query.filter(Student.school_id == school_id)
    return query.all()


def enqueue_diary_event(
    db: Session,
    class_id: int,
    log_date,
    lesson_id: int,
    subject: str,
    room: str | None,
    teacher_name: str | None,
    day_of_week: int,
    start_time: str,
    duration_minutes: int,
    homework: str | None,
    teacher_comment: str | None,
) -> None:
    """Diary content is identical for every student in `class_id` -- fanned
    out as one outbox row per student (see `_enqueue`'s entity_id choice
    below) so it reuses the existing per-student outbox/retry machinery
    untouched instead of a second, parallel broadcast path. Public Server
    dedupes these back down to one row on ingest (unique on school_id +
    local_lesson_id + log_date, not per-student).
    """
    for student in _students_for_class(db, class_id):
        parent, class_obj = _resolve_parent_and_class(db, student)
        if not parent:
            continue
        _enqueue(
            db,
            "diary",
            # A distinct id per fanned-out row (not the shared lesson_id) so
            # the sync worker's in-batch ordering guard -- which skips any
            # repeat (entity_type, entity_id) pair within one drain pass --
            # doesn't silently defer N-1 of these N identical-content rows to
            # later polls. See sync_worker.py::drain_outbox_once.
            student.id,
            "upsert",
            {
                "type": "diary",
                "operation": "upsert",
                "parent": _parent_payload(parent),
                "student": _student_payload(student, class_obj),
                "diary": {
                    "local_lesson_id": lesson_id,
                    "subject": subject,
                    "room": room,
                    "teacher_name": teacher_name,
                    "day_of_week": day_of_week,
                    "start_time": start_time,
                    "duration_minutes": duration_minutes,
                    "log_date": _iso(log_date),
                    "homework": homework,
                    "teacher_comment": teacher_comment,
                },
            },
        )


def enqueue_calendar_event(db: Session, event, operation: str = "upsert") -> None:
    students = _students_for_school_or_class(db, event.school_id, event.class_id)
    for student in students:
        parent, class_obj = _resolve_parent_and_class(db, student)
        if not parent:
            continue
        _enqueue(
            db,
            "calendar_event",
            student.id,
            operation,
            {
                "type": "calendar_event",
                "operation": operation,
                "parent": _parent_payload(parent),
                "student": _student_payload(student, class_obj),
                "calendar_event": {
                    "local_id": event.id,
                    "local_class_id": event.class_id,
                    "title": event.title,
                    "description": event.description,
                    "event_type": event.event_type,
                    "start_date": _iso(event.start_date),
                    "end_date": _iso(event.end_date),
                },
            },
        )


def enqueue_announcement_event(db: Session, announcement, operation: str = "upsert") -> None:
    students = _students_for_school_or_class(db, announcement.school_id, announcement.class_id)
    for student in students:
        parent, class_obj = _resolve_parent_and_class(db, student)
        if not parent:
            continue
        _enqueue(
            db,
            "announcement",
            student.id,
            operation,
            {
                "type": "announcement",
                "operation": operation,
                "parent": _parent_payload(parent),
                "student": _student_payload(student, class_obj),
                "announcement": {
                    "local_id": announcement.id,
                    "local_class_id": announcement.class_id,
                    "title": announcement.title,
                    "body": announcement.body,
                    "created_at": _iso(announcement.created_at),
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


# --------------------------------------------------------------------------
# Learning materials
#
# The odd ones out: these carry no parent/student block. Every other event
# type is fanned out once per affected pupil because the Public Server keys
# its data off a parent's family, but a material belongs to a *class* -- and
# pupils now sign in for themselves, so a pupil with no parent on file must
# still receive their homework. Sending one class-scoped event instead also
# avoids shipping the same question bank thirty times over.
# --------------------------------------------------------------------------

def _material_payload(material) -> dict:
    return {
        "local_id": material.id,
        "subject": material.subject,
        "title": material.title,
        "description": material.description,
        "teacher_name": material.teacher_name,
        "max_score": material.max_score,
        # Correct answers travel with the blocks: the Public Server marks
        # the work itself, and never sends `correct` on to a pupil's device.
        "blocks": [
            {
                "local_id": block.id,
                "position": block.position,
                "block_type": block.block_type,
                "body": block.body,
                "question_type": block.question_type,
                "options": block.options,
                "correct": block.correct,
                "points": block.points,
            }
            for block in sorted(material.blocks, key=lambda b: b.position)
        ],
    }


def enqueue_material_event(db: Session, material, operation: str = "upsert") -> None:
    _enqueue(
        db,
        "material",
        material.id,
        operation,
        {
            "type": "material",
            "operation": operation,
            "material": _material_payload(material),
        },
    )


def enqueue_material_assignment_event(db: Session, assignment, operation: str = "upsert") -> None:
    class_obj = (
        db.query(Class).filter(Class.id == assignment.class_id).first()
        if assignment.class_id
        else None
    )
    _enqueue(
        db,
        "material_assignment",
        assignment.id,
        operation,
        {
            "type": "material_assignment",
            "operation": operation,
            "material_assignment": {
                "local_id": assignment.id,
                "local_material_id": assignment.material_id,
                "local_class_id": assignment.class_id,
                "class_name": class_obj.name if class_obj else None,
                "teacher_name": assignment.teacher.full_name if assignment.teacher else None,
                "mode": assignment.mode,
                "due_at": _iso(assignment.due_at),
                "max_attempts": assignment.max_attempts,
                "published_at": _iso(assignment.published_at),
            },
        },
    )
