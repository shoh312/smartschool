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
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_director
from app.models.attendance_model import Attendance
from app.models.camera_position_model import CameraPosition
from app.models.class_model import Class
from app.models.director_model import Director
from app.models.journal_model import Grade
from app.models.lesson_attendance_model import LessonAttendance
from app.models.lesson_log_model import LessonLog
from app.models.lesson_model import Lesson
from app.models.material_model import Material, MaterialAssignment
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
    try:
        return _run_seed(db, student, class_id, teacher, since, until, present, rnd)
    except HTTPException:
        raise
    except Exception as exc:
        db.rollback()
        import traceback
        raise HTTPException(status_code=400, detail=f"seed failed: {type(exc).__name__}: {exc}\n{traceback.format_exc()[-1200:]}")


def _run_seed(db, student, class_id, teacher, since, until, present, rnd):
    student_id = student.id
    _wipe_previous(db, student_id)

    grades = attendance = lesson_rows = diary = 0
    seen_days: set[date] = set()
    quarters: set[tuple[int, int]] = set()

    for day, lesson in _lesson_days(db, class_id, since, until):
        hh, mm = (lesson.start_time or "09:00")[:5].split(":")
        start = datetime.combine(day, time(int(hh), int(mm)))
        came = rnd.random() < present

        # one day-level row per day, first lesson decides. A real detection
        # (any row that is not one of ours) always wins -- we never duplicate
        # or overwrite the school's own attendance.
        if day not in seen_days:
            seen_days.add(day)
            existing = db.query(Attendance).filter(Attendance.student_id == student_id, Attendance.attendance_date == day).first()
            if existing is not None and existing.confidence != DEMO_CONF:
                pass
            else:
                row = existing
                if came:
                    late = rnd.random() < 0.12
                    t_in = start + timedelta(minutes=rnd.randint(12, 25) if late else rnd.randint(-8, 4))
                    fields = dict(status="late" if late else "present", confidence=DEMO_CONF, attendance_date=day,
                                  time_in=t_in, time_out=t_in + timedelta(minutes=lesson.duration_minutes or 60),
                                  last_seen=t_in + timedelta(minutes=lesson.duration_minutes or 60), detected_at=t_in)
                else:
                    fields = dict(status="absent", confidence=DEMO_CONF, attendance_date=day, detected_at=start + timedelta(minutes=30))
                if row is None:
                    row = Attendance(student_id=student_id, camera_id=None, **fields)
                    db.add(row)
                else:
                    for k, v in fields.items():
                        setattr(row, k, v)
                db.flush()
                enqueue_attendance_event(db, row, operation="upsert", notify=False)
                attendance += 1

        if lesson.id is not None:
            la = db.query(LessonAttendance).filter(
                LessonAttendance.student_id == student_id, LessonAttendance.lesson_id == lesson.id,
                LessonAttendance.attendance_date == day).first()
            if la is None:
                db.add(LessonAttendance(student_id=student_id, lesson_id=lesson.id, camera_id=None,
                                        status="present" if came else "absent", confidence=DEMO_CONF,
                                        attendance_date=day, detected_at=start))
                db.flush()
                lesson_rows += 1
            elif la.confidence == DEMO_CONF:
                la.status = "present" if came else "absent"
                la.detected_at = start
                db.flush()
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



# --------------------------------------------------------------------------
# Filling the school with pupils, teachers and marks so every dashboard is
# full. Seeded pupils carry no visible label: they get no username and a
# hidden password_salt marker (SEED_MARK), so they read as ordinary pupils
# but can still be found and removed. Analytics compute from the grades
# table on the fly, so nothing needs a rebuild.

_FIRST = ["Аҳмад", "Фарҳод", "Ҷамшед", "Сино", "Наврӯз", "Шукруллоҳ", "Комрон", "Диловар", "Бахтиёр", "Рустам",
          "Нозия", "Мадина", "Зарина", "Гулнора", "Фарзона", "Ситора", "Малика", "Нигина", "Шаҳноза", "Дилноза",
          "Умед", "Парвиз", "Эмомалӣ", "Искандар", "Далер", "Сомон", "Меҳроҷ", "Фирдавс", "Ромиш", "Азиз"]
_LAST = ["Раҳимов", "Каримов", "Назаров", "Сафаров", "Ҷӯраев", "Тоҳиров", "Икромов", "Ашуров", "Ҳакимов", "Мирзоев",
         "Шарипов", "Валиев", "Қосимов", "Раҷабов", "Одинаев", "Сатторов", "Холов", "Юсупов", "Нуров", "Амонов"]
_LOW = ["Вазифаро иҷро накард", "Дар дарс фаъол набуд", "Мавзӯъро такрор кунад", "Диққат кам буд"]
_HIGH = ["Хуб кор кард", "Фаъол буд", "Ҷавоби пурра", ""]
# 18 subjects; which ones a class studies depends on its grade.
_SUBJECTS = [
    "Математика", "Забони тоҷикӣ", "Забони русӣ", "Забони англисӣ", "Адабиёт", "Табиатшиносӣ",
    "Информатика", "Таърих", "География", "Физика", "Химия", "Биология",
    "Алгебра", "Геометрия", "Тарбияи ҷисмонӣ", "Санъат", "Мусиқӣ", "Технология",
]
_PRIMARY = ["Математика", "Забони тоҷикӣ", "Забони русӣ", "Забони англисӣ", "Табиатшиносӣ",
            "Санъат", "Мусиқӣ", "Тарбияи ҷисмонӣ", "Технология"]
_MIDDLE = ["Алгебра", "Геометрия", "Забони тоҷикӣ", "Забони русӣ", "Забони англисӣ", "Адабиёт",
           "Физика", "Химия", "Биология", "Таърих", "География", "Информатика", "Тарбияи ҷисмонӣ"]
_SENIOR = ["Алгебра", "Геометрия", "Физика", "Химия", "Биология", "Забони англисӣ", "Адабиёт",
           "Таърих", "География", "Информатика", "Забони тоҷикӣ", "Тарбияи ҷисмонӣ"]


def _subjects_for_grade(g: int) -> list[str]:
    if g <= 4:
        return _PRIMARY
    if g <= 9:
        return _MIDDLE
    return _SENIOR


SEED_MARK = "s33d"   # hidden marker kept in password_salt; never shown in the UI


def _seeded_ids(db: Session, school_id: int) -> list[int]:
    return [r[0] for r in db.query(Student.id).filter(
        Student.school_id == school_id,
        (Student.password_salt == SEED_MARK) | (Student.username.like("demo\\_%", escape="\\"))
    ).all()]


def _delete_students(db, ids):
    """Delete pupils and every row that points at them, in an order that keeps
    foreign keys happy (notifications and attempts first)."""
    from app.models.notification_model import NotificationEvent
    from app.models.material_model import MaterialAttempt
    for chunk_start in range(0, len(ids), 500):
        chunk = ids[chunk_start:chunk_start + 500]
        att_ids = [r[0] for r in db.query(Attendance.id).filter(Attendance.student_id.in_(chunk)).all()]
        if att_ids:
            db.query(NotificationEvent).filter(NotificationEvent.attendance_id.in_(att_ids)).delete(synchronize_session=False)
        db.query(NotificationEvent).filter(NotificationEvent.student_id.in_(chunk)).delete(synchronize_session=False)
        db.query(MaterialAttempt).filter(MaterialAttempt.student_id.in_(chunk)).delete(synchronize_session=False)
        db.query(Grade).filter(Grade.student_id.in_(chunk)).delete(synchronize_session=False)
        db.query(Attendance).filter(Attendance.student_id.in_(chunk)).delete(synchronize_session=False)
        db.query(LessonAttendance).filter(LessonAttendance.student_id.in_(chunk)).delete(synchronize_session=False)
        db.query(Student).filter(Student.id.in_(chunk)).delete(synchronize_session=False)
        db.commit()


@router.post("/demo/bulk-wipe")
def bulk_wipe(db: Session = Depends(get_db), director: Director = Depends(get_current_director)):
    ids = _seeded_ids(db, director.school_id)
    if ids:
        _delete_students(db, ids)
    return {"removed_students": len(ids)}


def _translit(name: str) -> str:
    m = {"а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ж": "j", "з": "z", "и": "i", "й": "y",
         "к": "k", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u",
         "ф": "f", "х": "kh", "ц": "ts", "ч": "ch", "ш": "sh", "қ": "q", "ғ": "gh", "ҳ": "h", "ҷ": "j",
         "ӯ": "u", "ӣ": "i", "э": "e", "ю": "yu", "я": "ya", "ъ": ""}
    return "".join(m.get(ch, "") for ch in name.lower())


@router.post("/demo/rebalance")
def rebalance(
    per_class: int = 18,
    per_subject: int = 5,
    grades_per_subject: int = 6,
    days: int = 25,
    present: float = 0.93,
    seed: int = 7,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    """Spread every pupil (none deleted) across grade/section classes at most
    `per_class` each, creating classes as needed; make `per_subject` teachers
    for each subject; and give each seeded pupil marks in ~8 subjects."""
    import math
    from app.utils.security import hash_password

    per_class = max(1, min(30, per_class))
    rnd = random.Random(seed)
    school_id = director.school_id

    # normalise any earlier "demo_" pupils to the hidden marker, no visible label
    for s in db.query(Student).filter(Student.school_id == school_id, Student.username.like("demo\\_%", escape="\\")).all():
        s.username = None
        s.password_salt = SEED_MARK
        s.password_hash = None
    db.commit()

    # strip any leftover "[demo] " tag from every mark's comment, so nothing
    # visible ever reads "demo"
    db.query(Grade).filter(Grade.comment.like("[demo]%")).update(
        {Grade.comment: func.replace(func.replace(Grade.comment, "[demo] ", ""), "[demo]", "")}, synchronize_session=False)
    db.commit()

    # 1) teachers per subject (real-looking names and emails)
    subj_teachers: dict[str, list[int]] = {}
    created_teachers = 0
    for subject in _SUBJECTS:
        ids = [t.id for t in db.query(Teacher).filter(Teacher.school_id == school_id, Teacher.subject == subject).all()]
        n = 0
        while len(ids) < per_subject:
            fn, ln = rnd.choice(_FIRST), rnd.choice(_LAST)
            tln = _translit(ln)
            email = f"{_translit(fn)[:1]}.{tln}{n}@maktab.tj"
            n += 1
            if not tln or db.query(Teacher).filter(Teacher.email == email).first():
                continue
            t = Teacher(school_id=school_id, full_name=f"{ln} {fn}", subject=subject,
                        email=email, hashed_password=hash_password("1234"), is_active=True)
            db.add(t); db.flush(); ids.append(t.id); created_teachers += 1
        subj_teachers[subject] = ids
    db.commit()

    # 2) every pupil
    students = db.query(Student).filter(Student.school_id == school_id, Student.is_active == True).all()
    total = len(students)
    if total == 0:
        raise HTTPException(status_code=400, detail="No pupils to place")

    # 3) enough classes: grades 1..11, sections A.. as needed
    needed = max(33, math.ceil(total / per_class))
    sections = max(3, math.ceil(needed / 11))
    letters = [chr(ord("A") + i) for i in range(min(sections, 26))]
    wanted = [(g, f"{g}{L}") for g in range(1, 12) for L in letters]
    existing = {c.name: c for c in db.query(Class).filter(Class.school_id == school_id).all()}
    created_classes = 0
    for g, nm in wanted:
        if nm not in existing:
            db.add(Class(school_id=school_id, name=nm, grade=g)); created_classes += 1
    if created_classes:
        db.commit()
    classes = db.query(Class).filter(Class.school_id == school_id).order_by(Class.grade, Class.name).all()

    # 4) distribute pupils evenly, capped at per_class
    counts = {c.id: 0 for c in classes}
    rnd.shuffle(students)
    ci = 0
    for s in students:
        placed = False
        for _ in range(len(classes)):
            c = classes[ci % len(classes)]; ci += 1
            if counts[c.id] < per_class:
                s.class_id = c.id; counts[c.id] += 1; placed = True; break
        if not placed:
            c = classes[ci % len(classes)]; ci += 1
            s.class_id = c.id; counts[c.id] += 1
    db.commit()

    # 5) (re)seed marks + attendance for seeded pupils only; real pupils untouched
    seeded_ids = _seeded_ids(db, school_id)
    if seeded_ids:
        db.query(Grade).filter(Grade.student_id.in_(seeded_ids)).delete(synchronize_session=False)
        db.query(Attendance).filter(Attendance.student_id.in_(seeded_ids), Attendance.confidence == DEMO_CONF).delete(synchronize_session=False)
        db.commit()
    seeded = set(seeded_ids)

    today = date.today()
    school_days: list[date] = []
    d = today
    while len(school_days) < days:
        if d.weekday() != 6:
            school_days.append(d)
        d -= timedelta(days=1)
    school_days.reverse()

    weights = [3, 7, 14, 30, 30, 16]
    grade_by_class = {c.id: (c.grade or 5) for c in classes}
    grade_rows, att_rows = [], []
    for s in students:
        if s.id not in seeded:
            continue
        # marks only in the subjects this class's grade actually studies
        subs = _subjects_for_grade(int(grade_by_class.get(s.class_id, 5)))
        for subject in subs:
            tid = rnd.choice(subj_teachers[subject])
            for _ in range(rnd.randint(max(3, grades_per_subject - 1), grades_per_subject + 1)):
                gd = rnd.choice(school_days)
                v = rnd.choices([5, 6, 7, 8, 9, 10], weights=weights)[0]
                grade_rows.append(dict(
                    student_id=s.id, class_id=s.class_id, teacher_id=tid, subject=subject,
                    value=v, comment=(rnd.choice(_LOW) if v < 6 else rnd.choice(_HIGH)) or None,
                    grade_date=gd, quarter=quarter_for_date(gd), school_year=school_year_for_date(gd),
                ))
        for gd in school_days:
            came = rnd.random() < present
            late = came and rnd.random() < 0.12
            status = "late" if late else ("present" if came else "absent")
            att_rows.append(dict(
                student_id=s.id, camera_id=None, status=status, confidence=DEMO_CONF,
                attendance_date=gd, detected_at=datetime.combine(gd, time(9, rnd.randint(0, 20))),
            ))
        if len(grade_rows) >= 6000:
            db.bulk_insert_mappings(Grade, grade_rows); grade_rows = []; db.commit()
        if len(att_rows) >= 8000:
            db.bulk_insert_mappings(Attendance, att_rows); att_rows = []; db.commit()
    if grade_rows:
        db.bulk_insert_mappings(Grade, grade_rows); db.commit()
    if att_rows:
        db.bulk_insert_mappings(Attendance, att_rows); db.commit()

    sizes = dict(db.query(Class.name, func.count(Student.id)).join(Student, Student.class_id == Class.id)
                 .filter(Class.school_id == school_id, Student.is_active == True).group_by(Class.name).all())
    return {
        "pupils_placed": total, "created_classes": created_classes, "total_classes": len(classes),
        "created_teachers": created_teachers, "teachers_total": db.query(Teacher).filter(Teacher.school_id == school_id).count(),
        "max_class_size": max(sizes.values()) if sizes else 0, "per_class": per_class,
    }


@router.post("/demo/bulk-seed")
def bulk_seed(
    per_class: int = 18,
    per_subject: int = 5,
    grades_per_subject: int = 6,
    days: int = 25,
    present: float = 0.93,
    seed: int = 7,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    """Create fresh seeded pupils to fill grades 1..11 A/B/C up to per_class,
    then hand off to rebalance to place everyone, add teachers and seed marks."""
    per_class = max(1, min(30, per_class))
    rnd = random.Random(seed)
    school_id = director.school_id

    have = db.query(func.count(Student.id)).filter(Student.school_id == school_id, Student.is_active == True).scalar() or 0
    need = max(0, 33 * per_class - int(have))
    first_class = db.query(Class).filter(Class.school_id == school_id).first()
    rows = []
    for _ in range(need):
        rows.append(dict(
            school_id=school_id, class_id=(first_class.id if first_class else None), parent_id=None,
            first_name=rnd.choice(_FIRST), last_name=rnd.choice(_LAST),
            is_active=True, username=None, password_salt=SEED_MARK,
        ))
    if rows:
        db.bulk_insert_mappings(Student, rows)
        db.commit()

    return rebalance(per_class=per_class, per_subject=per_subject, grades_per_subject=grades_per_subject,
                     days=days, present=present, seed=seed, db=db, director=director)

def _reassign_teacher_refs(db, ids, keeper_id):
    """Move every row that points at these teachers onto the keeper, so the
    teachers can be deleted without tripping a foreign key."""
    db.query(Grade).filter(Grade.teacher_id.in_(ids)).update({Grade.teacher_id: keeper_id}, synchronize_session=False)
    db.query(Lesson).filter(Lesson.teacher_id.in_(ids)).update({Lesson.teacher_id: keeper_id}, synchronize_session=False)
    db.query(Material).filter(Material.teacher_id.in_(ids)).update({Material.teacher_id: keeper_id}, synchronize_session=False)
    db.query(MaterialAssignment).filter(MaterialAssignment.teacher_id.in_(ids)).update({MaterialAssignment.teacher_id: keeper_id}, synchronize_session=False)
    db.query(TeacherClass).filter(TeacherClass.teacher_id.in_(ids)).delete(synchronize_session=False)
    db.query(Teacher).filter(Teacher.id.in_(ids)).delete(synchronize_session=False)


@router.post("/demo/fix-teachers")
def fix_teachers(
    total: int = 100,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    """Tidy the staff room: drop English-named and test teachers (moving their
    marks to a real one first), keep the Tajik names, and make the count `total`
    with proper Tajik-named teachers across the 18 subjects. The teacher login
    s@cict.tj is kept."""
    import re
    from app.utils.security import hash_password

    total = max(1, min(300, total))
    rnd = random.Random(7)
    school_id = director.school_id
    latin = re.compile(r"[A-Za-z]")

    teachers = db.query(Teacher).filter(Teacher.school_id == school_id).all()
    # a keeper to inherit orphaned marks: a Tajik-named @maktab.tj teacher
    keeper = next((t for t in teachers if (t.email or "").endswith("@maktab.tj")), None)
    if keeper is None:
        keeper = Teacher(school_id=school_id, full_name=f"{rnd.choice(_LAST)} {rnd.choice(_FIRST)}",
                         subject=_SUBJECTS[0], email="teacher0@maktab.tj",
                         hashed_password=hash_password("1234"), is_active=True)
        db.add(keeper); db.commit()

    # remove: English/latin names, or "sinov"/"test" accounts -- but never the
    # working login s@cict.tj
    junk = [t for t in teachers if t.id != keeper.id and t.email != "s@cict.tj"
            and (bool(latin.search(t.full_name or "")) or "sinov" in (t.email or "").lower()
                 or "test" in (t.email or "").lower())]
    junk_ids = [t.id for t in junk]
    if junk_ids:
        _reassign_teacher_refs(db, junk_ids, keeper.id)
        db.commit()
    removed = len(junk_ids)

    # fix the login teacher's subject if it is not a real one
    nil = db.query(Teacher).filter(Teacher.email == "s@cict.tj").first()
    if nil and (nil.subject or "") not in _SUBJECTS:
        nil.subject = "Информатика"
        db.commit()

    # bring the count to `total` with Tajik-named teachers across subjects
    cur = db.query(Teacher).filter(Teacher.school_id == school_id).count()
    created = 0
    si = 0
    n = 0
    while cur < total:
        fn, ln = rnd.choice(_FIRST), rnd.choice(_LAST)
        tln = _translit(ln)
        email = f"{_translit(fn)[:1]}.{tln}{n}@maktab.tj"
        n += 1
        if not tln or db.query(Teacher).filter(Teacher.email == email).first():
            continue
        db.add(Teacher(school_id=school_id, full_name=f"{ln} {fn}", subject=_SUBJECTS[si % len(_SUBJECTS)],
                       email=email, hashed_password=hash_password("1234"), is_active=True))
        si += 1; cur += 1; created += 1
    if created:
        db.commit()

    # trim extras (never s@cict.tj), moving their marks to the keeper
    if cur > total:
        extra = (db.query(Teacher).filter(Teacher.school_id == school_id, Teacher.id != keeper.id,
                                          Teacher.email != "s@cict.tj")
                 .order_by(Teacher.id.desc()).limit(cur - total).all())
        eids = [t.id for t in extra]
        if eids:
            _reassign_teacher_refs(db, eids, keeper.id)
            db.commit()

    final = db.query(Teacher).filter(Teacher.school_id == school_id).count()
    return {"removed": removed, "created": created, "teachers_total": final}


@router.post("/demo/reset")
def reset(db: Session = Depends(get_db), director: Director = Depends(get_current_director)):
    """Undo the demo: remove all seeded pupils and demo teachers, and drop the
    now-empty classes, leaving the school's real pupils, teachers and classes."""
    school_id = director.school_id

    ids = _seeded_ids(db, school_id)
    if ids:
        _delete_students(db, ids)
    removed_students = len(ids)

    # demo teachers (created with @maktab.tj); move any leftover refs to a real teacher
    demo_teachers = db.query(Teacher).filter(Teacher.school_id == school_id, Teacher.email.like("%@maktab.tj")).all()
    keeper = (db.query(Teacher).filter(Teacher.school_id == school_id, ~Teacher.email.like("%@maktab.tj"),
                                       Teacher.email != None).first())
    removed_teachers = 0
    if demo_teachers and keeper:
        tids = [t.id for t in demo_teachers if t.id != keeper.id]
        if tids:
            _reassign_teacher_refs(db, tids, keeper.id)
            db.commit()
            removed_teachers = len(tids)

    # drop classes that are now empty and not wired to a camera or timetable
    removed_classes = 0
    for c in db.query(Class).filter(Class.school_id == school_id).all():
        if (db.query(Student.id).filter(Student.class_id == c.id).first() is None
                and db.query(CameraPosition.id).filter(CameraPosition.class_id == c.id).first() is None
                and db.query(Lesson.id).filter(Lesson.class_id == c.id).first() is None):
            db.delete(c); removed_classes += 1
    if removed_classes:
        db.commit()

    return {
        "removed_students": removed_students, "removed_teachers": removed_teachers,
        "removed_classes": removed_classes,
        "students_left": db.query(Student).filter(Student.school_id == school_id).count(),
        "teachers_left": db.query(Teacher).filter(Teacher.school_id == school_id).count(),
        "classes_left": db.query(Class).filter(Class.school_id == school_id).count(),
    }
