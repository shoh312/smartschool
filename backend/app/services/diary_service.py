from collections import defaultdict, deque
from datetime import date

from sqlalchemy.orm import Session

from app.models.journal_model import Grade
from app.models.lesson_log_model import LessonLog
from app.models.lesson_model import Lesson


def resolve_diary_for_class(
    db: Session,
    class_id: int,
    on_date: date,
    student_id: int | None = None,
) -> list[dict]:
    lessons = db.query(Lesson).filter(
        Lesson.class_id == class_id,
        Lesson.day_of_week == on_date.weekday(),
    ).order_by(Lesson.start_time.asc()).all()

    if not lessons:
        return []

    lesson_ids = [lesson.id for lesson in lessons]
    logs = {
        log.lesson_id: log
        for log in db.query(LessonLog).filter(
            LessonLog.lesson_id.in_(lesson_ids),
            LessonLog.log_date == on_date,
        ).all()
    }

    pending_grades: dict[str, deque[int]] = defaultdict(deque)
    if student_id is not None:
        for grade in db.query(Grade).filter(
            Grade.student_id == student_id,
            Grade.grade_date == on_date,
        ).order_by(Grade.id.asc()).all():
            pending_grades[grade.subject].append(grade.value)

    result = []
    for lesson in lessons:
        log = logs.get(lesson.id)
        queue = pending_grades.get(lesson.subject)
        result.append({
            "lesson_id": lesson.id,
            "subject": lesson.subject,
            "start_time": lesson.start_time,
            "duration_minutes": lesson.duration_minutes,
            "room": lesson.room,
            "teacher_id": lesson.teacher_id,
            "teacher_name": lesson.teacher_name,
            "homework": log.homework if log else None,
            "teacher_comment": log.teacher_comment if log else None,
            "grade": queue.popleft() if queue else None,
        })
    return result
