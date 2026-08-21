from collections import defaultdict, deque
from datetime import date, timedelta

from fastapi import APIRouter, Depends
from sqlalchemy import and_
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import PublicAuthActor, get_current_actor, get_owned_student
from app.models.diary_model import DiaryEntry
from app.models.grade_model import Grade
from app.schemas.diary_schema import DiaryEntryResponse

router = APIRouter(prefix="/diary", tags=["diary"])


@router.get("/{student_id}", response_model=list[DiaryEntryResponse])
def student_diary(
    student_id: int,
    on: date | None = None,
    db: Session = Depends(get_db),
    actor: PublicAuthActor = Depends(get_current_actor),
):
    student = get_owned_student(student_id, db, actor)

    on = on or date.today()
    entries = db.query(DiaryEntry).filter(
        DiaryEntry.school_id == student.school_id,
        DiaryEntry.local_class_id == student.local_class_id,
        DiaryEntry.log_date == on,
    ).order_by(DiaryEntry.start_time.asc()).all()

    # The lesson entries above are shared by the whole class (same subject/
    # homework for everyone) -- the grade is the one part of "today's
    # ruznoma" that's actually personal to this student, so it's looked up
    # separately and matched onto the day's lessons.
    #
    # Grades carry no lesson reference (they're recorded per student/subject/
    # date), so the match has to go through the subject name. Each grade is
    # handed to at most ONE lesson, in chronological order: a class with two
    # Math periods in a day used to show the same single grade on both cards,
    # and a student with two Math grades that day had one of them silently
    # dropped by the old dict-keyed-by-subject lookup.
    grades = db.query(Grade).filter(
        Grade.student_id == student.id,
        Grade.grade_date == on,
    ).order_by(Grade.id.asc()).all()

    pending_by_subject: dict[str, deque[int]] = defaultdict(deque)
    for grade in grades:
        pending_by_subject[grade.subject].append(grade.value)

    response: list[DiaryEntryResponse] = []
    for entry in entries:
        queue = pending_by_subject.get(entry.subject)
        response.append(
            DiaryEntryResponse(
                lesson_id=entry.local_lesson_id,
                subject=entry.subject,
                room=entry.room,
                teacher_name=entry.teacher_name,
                start_time=entry.start_time,
                duration_minutes=entry.duration_minutes,
                log_date=entry.log_date,
                homework=entry.homework,
                teacher_comment=entry.teacher_comment,
                grade=queue.popleft() if queue else None,
            )
        )
    return response


@router.get("/homework/{student_id}", response_model=list[DiaryEntryResponse])
def student_homework(
    student_id: int,
    days: int = 14,
    db: Session = Depends(get_db),
    actor: PublicAuthActor = Depends(get_current_actor),
):
    """Homework across several days (not just one), for a "Uy vazifalari"
    list view -- reads the same already-synced DiaryEntry rows the single-day
    diary reads, just filtered to entries that have homework set and spread
    across a date range instead of one exact date.
    """
    student = get_owned_student(student_id, db, actor)

    today = date.today()
    entries = db.query(DiaryEntry).filter(
        DiaryEntry.school_id == student.school_id,
        DiaryEntry.local_class_id == student.local_class_id,
        and_(DiaryEntry.homework.isnot(None), DiaryEntry.homework != ""),
        DiaryEntry.log_date >= today - timedelta(days=3),
        DiaryEntry.log_date <= today + timedelta(days=days),
    ).order_by(DiaryEntry.log_date.desc(), DiaryEntry.start_time.asc()).all()

    return [
        DiaryEntryResponse(
            lesson_id=entry.local_lesson_id,
            subject=entry.subject,
            room=entry.room,
            teacher_name=entry.teacher_name,
            start_time=entry.start_time,
            duration_minutes=entry.duration_minutes,
            log_date=entry.log_date,
            homework=entry.homework,
            teacher_comment=entry.teacher_comment,
        )
        for entry in entries
    ]
