"""Demo data for one pupil: a term of attendance, marks and homework.

POST /students/{id}/seed-demo?since=2026-01-01&present=0.95

Walks every lesson day of the pupil's class from `since` to yesterday
(from the Lesson timetable; camera positions when there is no timetable),
and for each lesson day writes:
  * a day-level Attendance row (present, sometimes late; absent at the
    given rate) and a per-lesson LessonAttendance row that agrees with it;
  * a mark on roughly every second lesson (skewed towards 8-10, with a
    short comment on the low ones);
  * homework in the class diary (shared by the whole group).

Nothing here sends a notification: rows are written straight to the
database and only the sync events go out, with `notify` off. Everything
created carries the marker "[demo]" (grade comment) or confidence -1
(attendance rows), so a second call first removes the previous seed and the
pupil's real data stays untouched.
"""

import random
from datetime import date, datetime, time, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_director
from app.models.attendance_model import Attendance
from app.models.camera_position_model import CameraPosition
from app.models.director_model import Director
from app.models.journal_model import Grade
from app.models.lesson_attendance_model import LessonAttendance
from app.models.lesson_log_model import LessonLog
from app.models.lesson_model import Lesson
from app.models.student import Student
from app.models.teacher_model import Teacher, TeacherClass
from app.services import analytics_service
from app.services.sync_outbox_service import (
    enqueue_attendance_event,
    enqueue_diary_event,
    enqueue_grade_event,
    enqueue_student_analytics_event,
)
from app.utils.academic_calendar import quarter_for_date, school_year_for_date

router = APIRouter(tags=["demo"])

MARK = "[demo]"
DEMO_CONF = -1.0   # confidence sentinel: no real detection ever writes a negative value

HOMEWORK = [
    "Машқҳои 1–5 аз дафтари корӣ", "Лоиҳаро ба GitHub гузоред", "Саҳифаи 24–27-ро хонед ва конспект нависед",
    "Функсияи ҳисобкунандаро нависед", "Тестро дар илова ҳал кунед", "Ба саволҳои охири боб ҷавоб диҳед",
    "Мисолҳои 3–8-ро иҷро кунед", "Презентатсия барои дарси оянда", "Кодро такмил диҳед ва санҷед",
]
LOW_COMMENTS = ["Вазифаро иҷро накард", "Дар дарс фаъол набуд", "Мавзӯъро такрор кунад", "Диққат кам буд"]
HIGH_COMMENTS = ["Хуб кор кард", "Фаъол буд", "Ҷавоби пурра", ""]


def _lesson_days(db: Session, class_id: int, since: date, until: date):
    lessons = db.query(Lesson).filter(Lesson.class_id == class_id).all()
    by_dow: dict[int, list[Lesson]] = {}
    for l in lessons:
        by_dow.setdefault(int(l.day_of_week), []).append(l)
    if not by_dow:
        for p in db.query(CameraPosition).filter(CameraPosition.class_id == class_id).all():
            days = range(7) if p.day_of_week is None else [int(p.day_of_week)]
            for d in days:
                if d == 6:
                    continue
                by_dow.setdefault(d, []).append(Lesson(id=None, class_id=class_id, subject=p.subject or "", day_of_week=d, start_time=p.start_time, duration_minutes=60))
    day = since
    while day <= until:
        for l in by_dow.get(day.weekday(), []):
            yield day, l
        day += timedelta(days=1)


def _wipe_previous(db: Session, student_id: int):
    db.query(Grade).filter(Grade.student_id == student_id, Grade.comment.like(MARK + "%")).delete(synchronize_session=False)
    db.query(Attendance).filter(Attendance.student_id == student_id, Attendance.confidence == DEMO_CONF).delete(synchronize_session=False)
    db.query(LessonAttendance).filter(LessonAttendance.student_id == student_id, LessonAttendance.confidence == DEMO_CONF).delete(synchronize_session=False)
    db.flush()


@router.post("/students/{student_id}/seed-demo")
def seed_demo(
    student_id: int,
    since: date = date(2026, 1, 1),
    present: float = 0.95,
    seed: int = 7,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    student = db.query(Student).filter(Student.id == student_id, Student.school_id == director.school_id).first()
    if not student or not student.class_id:
        raise HTTPException(status_code=404, detail="Student not found or has no class")
    class_id = student.class_id
    teacher = (
        db.query(Teacher).join(TeacherClass, TeacherClass.teacher_id == Teacher.id)
        .filter(TeacherClass.class_id == class_id).first()
        or db.query(Teacher).filter(Teacher.school_id == director.school_id).first()
    )
    if not teacher:
        raise HTTPException(status_code=400, detail="No teacher to sign the marks")

    rnd = random.Random(seed * 1000 + student_id)
    until = date.today() - timedelta(days=1)
    _wipe_previous(db, student_id)

    grades = attendance = lesson_rows = diary = 0
    seen_days: set[date] = set()
    quarters: set[tuple[int, int]] = set()

    for day, lesson in _lesson_days(db, class_id, since, until):
        hh, mm = (lesson.start_time or "09:00")[:5].split(":")
        start = datetime.combine(day, time(int(hh), int(mm)))
        came = rnd.random() < present

        # one day-level row per day, first lesson decides
        if day not in seen_days:
            seen_days.add(day)
            if came:
                late = rnd.random() < 0.12
                t_in = start + timedelta(minutes=rnd.randint(12, 25) if late else rnd.randint(-8, 4))
                row = Attendance(student_id=student_id, camera_id=None, status="late" if late else "present",
                                 confidence=DEMO_CONF, attendance_date=day, time_in=t_in, time_out=t_in + timedelta(minutes=lesson.duration_minutes or 60),
                                 last_seen=t_in + timedelta(minutes=lesson.duration_minutes or 60), detected_at=t_in)
            else:
                row = Attendance(student_id=student_id, camera_id=None, status="absent", confidence=DEMO_CONF, attendance_date=day, detected_at=start + timedelta(minutes=30))
            db.add(row)
            db.flush()
            enqueue_attendance_event(db, row, operation="upsert", notify=False)
            attendance += 1

        if lesson.id is not None:
            db.add(LessonAttendance(student_id=student_id, lesson_id=lesson.id, camera_id=None,
                                    status="present" if came else "absent", confidence=DEMO_CONF,
                                    attendance_date=day, detected_at=start))
            lesson_rows += 1

            # homework for the whole group on that lesson (only if nobody wrote one)
            log = db.query(LessonLog).filter(LessonLog.lesson_id == lesson.id, LessonLog.log_date == day).first()
            if log is None and rnd.random() < 0.7:
                log = LessonLog(lesson_id=lesson.id, log_date=day, homework=rnd.choice(HOMEWORK), teacher_comment=None)
                db.add(log)
                db.flush()
                enqueue_diary_event(db, class_id, day, lesson.id, lesson.subject, lesson.room, teacher.full_name,
                                    int(lesson.day_of_week), lesson.start_time, lesson.duration_minutes or 60, log.homework, None)
                diary += 1

        # a mark on about half the lessons the pupil attended
        if came and rnd.random() < 0.55:
            value = rnd.choices([5, 6, 7, 8, 9, 10], weights=[3, 7, 14, 30, 30, 16])[0]
            comment = MARK + " " + (rnd.choice(LOW_COMMENTS) if value < 6 else rnd.choice(HIGH_COMMENTS))
            g = Grade(student_id=student_id, class_id=class_id, teacher_id=teacher.id, subject=lesson.subject or "",
                      value=value, comment=comment.strip(), grade_date=day,
                      quarter=quarter_for_date(day), school_year=school_year_for_date(day))
            db.add(g)
            db.flush()
            enqueue_grade_event(db, g, operation="upsert")
            quarters.add((g.quarter, g.school_year))
            grades += 1

    db.commit()

    for quarter, year in quarters:
        overview = analytics_service.build_student_overview(db, student, quarter, year)
        enqueue_student_analytics_event(db, student, overview)
    db.commit()

    return {"student_id": student_id, "class_id": class_id, "since": since.isoformat(), "until": until.isoformat(),
            "days": attendance, "lesson_rows": lesson_rows, "grades": grades, "homework": diary}
