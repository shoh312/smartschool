"""Building a first weekly timetable from what the school already knows.

Three lessons existed for eight classes, and the diary, per-lesson
attendance and "which lesson is on right now" all read from that table --
so most of the app was looking at an empty week. The school has already
recorded which teacher takes which subject in which class; this lays those
out across Monday to Friday so there is something real to correct.

It is a draft, not a plan. Nobody's actual timetable comes out of a
round-robin, and the director edits it afterwards -- but correcting a week
is a different job from typing one from nothing.
"""

from sqlalchemy.orm import Session

from app.models.class_model import Class
from app.models.lesson_attendance_model import LessonAttendance
from app.models.lesson_log_model import LessonLog
from app.models.lesson_model import Lesson
from app.models.teacher_model import TeacherClass

# Monday-Friday. Saturday is a school day in some places -- the caller can
# raise this, but a six-day default would be wrong more often than right.
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
    """A class already has lessons that carry real data behind them."""


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
    """Lay out a week for every class that has subjects assigned.

    Teacher clashes are the one thing a generated timetable must get right:
    a teacher placed in two classrooms at once is not a draft to correct,
    it's a timetable nobody can read. Scheduling the whole school in one
    pass is what makes that check possible.
    """
    classes = (
        db.query(Class)
        .filter(Class.school_id == school_id)
        .order_by(Class.name)
        .all()
    )
    slots = _slot_times(lessons_per_day, first_lesson)

    # (day, slot) -> teacher ids already teaching then.
    busy: dict[tuple[int, int], set[int]] = {}
    skipped: list[str] = []
    created = 0
    cleared = 0

    # Existing lessons still count towards clashes -- a class we're leaving
    # alone still occupies its teacher.
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
            # Nothing to schedule; a class with no subjects assigned is a
            # setup problem, not something to invent lessons for.
            skipped.append(f"{school_class.name}: fan biriktirilmagan")
            continue

        existing = db.query(Lesson).filter(Lesson.class_id == school_class.id).all()

        if existing and replace:
            if _has_history(db, [lesson.id for lesson in existing]):
                # Deleting these would strip the diary entries and lesson
                # attendance hanging off them.
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

        # Whatever survived keeps its place; the generator fills the gaps
        # around it. A class with two real lessons is barely better off than
        # an empty one, and skipping it outright left it that way.
        occupied = {
            (lesson.day_of_week, slots.index(lesson.start_time))
            for lesson in existing
            if lesson.start_time in slots
        }

        # Round-robin so every subject gets a comparable share of the week
        # instead of the first one filling Monday.
        index = 0
        for day in range(days):
            for slot in range(lessons_per_day):
                key = (day, slot)
                if key in occupied:
                    continue
                taken = busy.setdefault(key, set())

                # Walk the subject list until one whose teacher is free.
                chosen = None
                for offset in range(len(subjects)):
                    candidate = subjects[(index + offset) % len(subjects)]
                    if candidate.teacher_id not in taken:
                        chosen = candidate
                        index = (index + offset + 1) % len(subjects)
                        break
                if chosen is None:
                    # Every teacher for this class is already busy then --
                    # a free period rather than a double-booking.
                    continue

                db.add(
                    Lesson(
                        class_id=school_class.id,
                        subject=chosen.subject,
                        day_of_week=day,
                        start_time=slots[slot],
                        duration_minutes=LESSON_MINUTES,
                        teacher_id=chosen.teacher_id,
                        # Left empty: the school hasn't recorded a room per
                        # class anywhere, and inventing one would put a
                        # wrong number in front of pupils.
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
