from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_director
from app.models.class_model import Class
from app.models.director_model import Director
from app.models.lesson_attendance_model import LessonAttendance
from app.models.lesson_model import Lesson
from app.models.student import Student
from app.schemas.lesson_schema import (
    LessonCreate,
    LessonResponse,
    LessonRosterEntry,
    LessonStatusEntry,
    LessonUpdate,
)
from app.services import timetable_service
from app.services.attendance_service import get_lesson_attendance

router = APIRouter(tags=["lessons"])


def _require_class(db: Session, class_id: int, director: Director) -> Class:
    school_class = db.query(Class).filter(
        Class.id == class_id,
        Class.school_id == director.school_id,
    ).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Class not found")
    return school_class


def _require_lesson(db: Session, lesson_id: int, director: Director) -> Lesson:
    lesson = db.query(Lesson).join(Class, Class.id == Lesson.class_id).filter(
        Lesson.id == lesson_id,
        Class.school_id == director.school_id,
    ).first()
    if not lesson:
        raise HTTPException(status_code=404, detail="Lesson not found")
    return lesson


@router.post("/lessons", response_model=LessonResponse, dependencies=[Depends(get_current_director)])
def create_lesson(
    payload: LessonCreate,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    _require_class(db, payload.class_id, director)
    lesson = Lesson(
        class_id=payload.class_id,
        subject=payload.subject,
        day_of_week=payload.day_of_week,
        start_time=payload.start_time,
        duration_minutes=payload.duration_minutes,
        teacher_id=payload.teacher_id,
        room=payload.room,
    )
    db.add(lesson)
    db.commit()
    db.refresh(lesson)
    return lesson


@router.get("/lessons", response_model=list[LessonResponse], dependencies=[Depends(get_current_director)])
def list_lessons(
    class_id: int,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    _require_class(db, class_id, director)
    return db.query(Lesson).filter(Lesson.class_id == class_id).order_by(
        Lesson.day_of_week.asc(), Lesson.start_time.asc()
    ).all()


@router.patch("/lessons/{lesson_id}", response_model=LessonResponse, dependencies=[Depends(get_current_director)])
def update_lesson(
    lesson_id: int,
    payload: LessonUpdate,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    lesson = _require_lesson(db, lesson_id, director)
    if payload.subject is not None:
        lesson.subject = payload.subject
    if payload.day_of_week is not None:
        lesson.day_of_week = payload.day_of_week
    if payload.start_time is not None:
        lesson.start_time = payload.start_time
    if payload.duration_minutes is not None:
        lesson.duration_minutes = payload.duration_minutes
    if payload.teacher_id is not None:
        lesson.teacher_id = payload.teacher_id
    if payload.room is not None:
        lesson.room = payload.room
    db.commit()
    db.refresh(lesson)
    return lesson


@router.delete("/lessons/{lesson_id}", status_code=204, dependencies=[Depends(get_current_director)])
def delete_lesson(
    lesson_id: int,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    lesson = _require_lesson(db, lesson_id, director)
    has_attendance = db.query(LessonAttendance).filter(
        LessonAttendance.lesson_id == lesson_id
    ).first() is not None
    if has_attendance:
        # Recorded attendance history exists for this lesson -- deleting it
        # would either cascade-destroy that history or hit the FK constraint
        # and 500, so ask the caller to edit the schedule going forward
        # (e.g. change start_time) instead of deleting a slot with a past.
        raise HTTPException(
            status_code=409,
            detail="This lesson has recorded attendance and cannot be deleted. Edit it instead.",
        )
    db.delete(lesson)
    db.commit()


@router.get(
    "/attendance/lesson-status",
    response_model=list[LessonStatusEntry],
    dependencies=[Depends(get_current_director)],
)
def lesson_attendance_status(
    class_id: int,
    on: date | None = None,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    """Per-lesson roster view for a class/day: which students were present,
    late, or absent for each lesson -- the fine-grained counterpart to
    `/attendance/live-status`, which only knows about the whole day.
    """
    _require_class(db, class_id, director)
    on = on or date.today()

    lessons = db.query(Lesson).filter(
        Lesson.class_id == class_id,
        Lesson.day_of_week == on.weekday(),
    ).order_by(Lesson.start_time.asc()).all()

    students = db.query(Student).filter(
        Student.class_id == class_id,
        Student.is_active == True,
    ).order_by(Student.first_name.asc()).all()

    response = []
    for lesson in lessons:
        roster = []
        for student in students:
            attendance = get_lesson_attendance(db, student.id, lesson.id, on)
            roster.append(LessonRosterEntry(
                student_id=student.id,
                first_name=student.first_name,
                last_name=student.last_name,
                status=attendance.status if attendance else "not_detected",
            ))
        response.append(LessonStatusEntry(
            lesson_id=lesson.id,
            subject=lesson.subject,
            start_time=lesson.start_time,
            duration_minutes=lesson.duration_minutes,
            students=roster,
        ))
    return response


@router.post("/lessons/generate-timetable", dependencies=[Depends(get_current_director)])
def generate_timetable(
    days: int = 5,
    lessons_per_day: int = 6,
    first_lesson: str = "08:00",
    replace: bool = False,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    """Lay out a draft week for every class from its assigned subjects.

    A starting point to correct, not a finished timetable -- but the table
    was nearly empty, and the diary, per-lesson attendance and "which
    lesson is on now" all read from it.

    Classes that already have lessons are left alone unless `replace`, and
    even then any lesson with a diary entry or attendance behind it is
    skipped rather than deleted along with its history.
    """
    return timetable_service.generate_for_school(
        db,
        director.school_id,
        days=max(1, min(days, 7)),
        lessons_per_day=max(1, min(lessons_per_day, 10)),
        first_lesson=first_lesson,
        replace=replace,
    )
