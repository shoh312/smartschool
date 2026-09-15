
from sqlalchemy.orm import Session

from app.models.class_model import Class
from app.models.lesson_attendance_model import LessonAttendance
from app.models.lesson_log_model import LessonLog
from app.models.lesson_model import Lesson
from app.models.teacher_model import TeacherClass

DEFAULT_DAYS = 5
DEFAULT_LESSONS_PER_DAY = 6
LESSON_MINUTES = 45
BREAK_MINUTES = 10
FIRST_LESSON = "08:00"


def _slot_times(count: int, first: str = FIRST_LESSON) -> list[str]:
    hour, minute = (int(part) for part in first.split(":"))
    times = []
    for _ in range(count):
        times.append(f"{hour:02d}:{minute:02d}")
        minute += LESSON_MINUTES + BREAK_MINUTES
        hour, minute = hour + minute // 60, minute % 60
    return times


class TimetableConflict(Exception):
    pass


def _has_history(db: Session, lesson_ids: list[int]) -> bool:
    if not lesson_ids:
        return False
    logged = db.query(LessonLog).filter(LessonLog.lesson_id.in_(lesson_ids)).first()
    attended = db.query(LessonAttendance).filter(
        LessonAttendance.lesson_id.in_(lesson_ids)
    ).first()
    return logged is not None or attended is not None


def generate_for_school(
    db: Session,
    school_id: int,
    *,
    days: int = DEFAULT_DAYS,
    lessons_per_day: int = DEFAULT_LESSONS_PER_DAY,
    first_lesson: str = FIRST_LESSON,
    replace: bool = False,
) -> dict:
    classes = (
        db.query(Class)
        .filter(Class.school_id == school_id)
        .order_by(Class.name)
        .all()
    )
    slots = _slot_times(lessons_per_day, first_lesson)

    busy: dict[tuple[int, int], set[int]] = {}
    skipped: list[str] = []
    created = 0
    cleared = 0

    for lesson in db.query(Lesson).join(Class, Class.id == Lesson.class_id).filter(
        Class.school_id == school_id
    ).all():
        if lesson.teacher_id and lesson.start_time in slots:
            key = (lesson.day_of_week, slots.index(lesson.start_time))
            busy.setdefault(key, set()).add(lesson.teacher_id)

    for school_class in classes:
        assignments = (
            db.query(TeacherClass)
            .filter(TeacherClass.class_id == school_class.id)
            .all()
        )
        subjects = [a for a in assignments if (a.subject or "").strip()]
        if not subjects:
            skipped.append(f"{school_class.name}: fan biriktirilmagan")
            continue

        existing = db.query(Lesson).filter(Lesson.class_id == school_class.id).all()

        if existing and replace:
            if _has_history(db, [lesson.id for lesson in existing]):
                skipped.append(f"{school_class.name}: darslarida yozuvlar bor, faqat bo'sh joylar to'ldirildi")
            else:
                for lesson in existing:
                    if lesson.teacher_id and lesson.start_time in slots:
                        key = (lesson.day_of_week, slots.index(lesson.start_time))
                        busy.get(key, set()).discard(lesson.teacher_id)
                    db.delete(lesson)
                    cleared += 1
                existing = []
                db.flush()

        occupied = {
            (lesson.day_of_week, slots.index(lesson.start_time))
            for lesson in existing
            if lesson.start_time in slots
        }

        index = 0
        for day in range(days):
            for slot in range(lessons_per_day):
                key = (day, slot)
                if key in occupied:
                    continue
                taken = busy.setdefault(key, set())

                chosen = None
                for offset in range(len(subjects)):
                    candidate = subjects[(index + offset) % len(subjects)]
                    if candidate.teacher_id not in taken:
                        chosen = candidate
                        index = (index + offset + 1) % len(subjects)
                        break
                if chosen is None:
                    continue

                db.add(
                    Lesson(
                        class_id=school_class.id,
                        subject=chosen.subject,
                        day_of_week=day,
                        start_time=slots[slot],
                        duration_minutes=LESSON_MINUTES,
                        teacher_id=chosen.teacher_id,
                        room=None,
                    )
                )
                taken.add(chosen.teacher_id)
                created += 1

    db.commit()
    return {
        "created_count": created,
        "replaced_count": cleared,
        "skipped": skipped,
        "slots": slots,
        "days": days,
    }
