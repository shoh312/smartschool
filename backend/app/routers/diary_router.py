from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import AuthActor, get_current_actor
from app.models.class_model import Class
from app.models.lesson_log_model import LessonLog
from app.models.lesson_model import Lesson
from app.models.student import Student
from app.schemas.lesson_schema import DiaryEntryOut, DiaryLogUpdate
from app.services import diary_service
from app.services.sync_outbox_service import enqueue_diary_event

router = APIRouter(prefix="/diary", tags=["diary"])


def _require_director_or_teacher(actor: AuthActor) -> None:
    if actor.role not in ("director", "teacher"):
        raise HTTPException(status_code=403, detail="Director or teacher access required")


def _actor_school_id(actor: AuthActor) -> int | None:
    return actor.director.school_id if actor.role == "director" else actor.teacher.school_id


@router.get("", response_model=list[DiaryEntryOut])
def get_diary(
    class_id: int,
    on: date | None = None,
    student_id: int | None = None,
    db: Session = Depends(get_db),
    actor: AuthActor = Depends(get_current_actor),
):
    _require_director_or_teacher(actor)
    school_class = db.query(Class).filter(Class.id == class_id).first()
    if not school_class or school_class.school_id != _actor_school_id(actor):
        raise HTTPException(status_code=404, detail="Class not found")

    # A diary really belongs to one pupil, so staff can narrow the class
    # view down to a single student and see their grades alongside the
    # (class-wide) lessons and homework.
    if student_id is not None:
        student = db.query(Student).filter(
            Student.id == student_id,
            Student.class_id == class_id,
        ).first()
        if not student:
            raise HTTPException(status_code=404, detail="Student not found in that class")

    return diary_service.resolve_diary_for_class(
        db, class_id, on or date.today(), student_id=student_id
    )


@router.patch("/{lesson_id}", response_model=DiaryEntryOut)
def update_diary_log(
    lesson_id: int,
    payload: DiaryLogUpdate,
    on: date | None = None,
    db: Session = Depends(get_db),
    actor: AuthActor = Depends(get_current_actor),
):
    _require_director_or_teacher(actor)
    lesson = db.query(Lesson).join(Class, Class.id == Lesson.class_id).filter(
        Lesson.id == lesson_id,
        Class.school_id == _actor_school_id(actor),
    ).first()
    if not lesson:
        raise HTTPException(status_code=404, detail="Lesson not found")

    # Homework and the teacher's note are that teacher's own record of the
    # lesson, so only the teacher this lesson is assigned to may write them.
    # A director can read every class's diary but not author entries in it --
    # previously any director could overwrite any teacher's homework.
    if actor.role != "teacher" or lesson.teacher_id != actor.teacher.id:
        raise HTTPException(
            status_code=403,
            detail="Only the teacher assigned to this lesson can edit its diary",
        )

    on = on or date.today()
    # A log written for a date whose weekday isn't one this lesson runs on
    # would be stored and synced to the Public Server (parents/students would
    # see it) yet never appear again in this local diary, which only resolves
    # lessons matching `on_date.weekday()` -- silently unreachable, uneditable
    # data. Reject it instead.
    if on.weekday() != lesson.day_of_week:
        raise HTTPException(
            status_code=400,
            detail="This lesson does not run on that weekday",
        )

    log = db.query(LessonLog).filter(
        LessonLog.lesson_id == lesson_id,
        LessonLog.log_date == on,
    ).first()
    if not log:
        log = LessonLog(lesson_id=lesson_id, log_date=on)
        db.add(log)
    if payload.homework is not None:
        log.homework = payload.homework
    if payload.teacher_comment is not None:
        log.teacher_comment = payload.teacher_comment
    db.commit()
    db.refresh(lesson)
    db.refresh(log)

    enqueue_diary_event(
        db,
        lesson.class_id,
        on,
        lesson.id,
        lesson.subject,
        lesson.room,
        lesson.teacher_name,
        lesson.day_of_week,
        lesson.start_time,
        lesson.duration_minutes,
        log.homework,
        log.teacher_comment,
    )
    db.commit()

    return DiaryEntryOut(
        lesson_id=lesson.id,
        subject=lesson.subject,
        start_time=lesson.start_time,
        duration_minutes=lesson.duration_minutes,
        room=lesson.room,
        teacher_id=lesson.teacher_id,
        teacher_name=lesson.teacher_name,
        homework=log.homework,
        teacher_comment=log.teacher_comment,
    )
