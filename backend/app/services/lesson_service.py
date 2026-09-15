from datetime import date, datetime, time, timedelta

from sqlalchemy.orm import Session

from app.models.lesson_model import Lesson


def _parse_start(lesson: Lesson) -> time | None:
    try:
        hh, mm = map(int, lesson.start_time.split(":"))
        return time(hh, mm)
    except (ValueError, AttributeError):
        return None


def _end_time(lesson: Lesson, start: time) -> time:
    end_dt = datetime(2000, 1, 1, start.hour, start.minute) + timedelta(minutes=lesson.duration_minutes)
    return end_dt.time()


def active_lesson_for_class(db: Session, class_id: int, now: datetime | None = None) -> Lesson | None:
    now = now or datetime.now()
    current_time = now.time()
    lessons = db.query(Lesson).filter(
        Lesson.class_id == class_id,
        Lesson.day_of_week == now.weekday(),
    ).all()

    for lesson in lessons:
        start = _parse_start(lesson)
        if start is None:
            continue
        end = _end_time(lesson, start)
        if start <= current_time < end:
            return lesson
    return None


def finished_lessons_today(db: Session, now: datetime | None = None) -> list[Lesson]:
    now = now or datetime.now()
    current_time = now.time()
    lessons = db.query(Lesson).filter(Lesson.day_of_week == now.weekday()).all()

    finished = []
    for lesson in lessons:
        start = _parse_start(lesson)
        if start is None:
            continue
        if _end_time(lesson, start) <= current_time:
            finished.append(lesson)
    return finished
