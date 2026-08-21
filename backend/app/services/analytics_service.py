from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.class_model import Class
from app.models.journal_model import Grade
from app.models.lesson_attendance_model import LessonAttendance
from app.models.student import Student
from app.utils.academic_calendar import current_quarter, current_school_year, quarter_date_range


def subject_averages(db: Session, student_id: int, quarter: int, school_year: int) -> list[tuple[str, float, int]]:
    rows = db.query(
        Grade.subject,
        func.avg(Grade.value),
        func.count(Grade.id),
    ).filter(
        Grade.student_id == student_id,
        Grade.quarter == quarter,
        Grade.school_year == school_year,
    ).group_by(Grade.subject).all()
    return [(subject, round(float(avg), 2), int(count)) for subject, avg, count in rows]


def class_subject_averages(
    db: Session, student_ids: list[int], quarter: int, school_year: int
) -> list[dict]:
    """How a whole group of pupils is doing, subject by subject.

    Averaged over every mark in the subject rather than over per-pupil
    averages: a pupil with twelve marks in maths and one in music should
    weigh the same as anyone else in maths, and averaging averages would
    instead let a single-mark pupil swing the subject as hard as a
    well-assessed one.

    ``student_count`` is how many pupils have at least one mark in that
    subject, which is what tells a director whether "4.2 in music" is the
    class or just the two pupils who were graded.
    """
    if not student_ids:
        return []

    rows = db.query(
        Grade.subject,
        func.avg(Grade.value),
        func.count(Grade.id),
        func.count(func.distinct(Grade.student_id)),
    ).filter(
        Grade.student_id.in_(student_ids),
        Grade.quarter == quarter,
        Grade.school_year == school_year,
    ).group_by(Grade.subject).all()

    breakdown = [
        {
            "subject": subject,
            "average": round(float(avg), 2),
            "grade_count": int(grade_count),
            "student_count": int(student_count),
        }
        for subject, avg, grade_count, student_count in rows
    ]
    # Strongest first: the screen reads top-down as best-to-worst, so the
    # subject needing attention is the last row rather than something the
    # reader has to hunt for.
    breakdown.sort(key=lambda row: row["average"], reverse=True)
    return breakdown


def overall_average(db: Session, student_id: int, quarter: int, school_year: int) -> float | None:
    avg = db.query(func.avg(Grade.value)).filter(
        Grade.student_id == student_id,
        Grade.quarter == quarter,
        Grade.school_year == school_year,
    ).scalar()
    return round(float(avg), 2) if avg is not None else None


def overall_averages_for_students(
    db: Session, student_ids: list[int], quarter: int, school_year: int
) -> dict[int, float]:
    if not student_ids:
        return {}
    rows = db.query(Grade.student_id, func.avg(Grade.value)).filter(
        Grade.student_id.in_(student_ids),
        Grade.quarter == quarter,
        Grade.school_year == school_year,
    ).group_by(Grade.student_id).all()
    return {student_id: round(float(avg), 2) for student_id, avg in rows}


def _ranked_ids(student_ids: list[int], averages: dict[int, float]) -> list[int]:
    # Students with no grades this quarter have no average to compare --
    # rank them after everyone who does, rather than treating a missing
    # average as a 0 (which would unfairly bury a student who simply hasn't
    # been graded yet this quarter below one who's genuinely failing).
    return sorted(
        student_ids,
        key=lambda sid: (averages.get(sid) is None, -(averages.get(sid) or 0)),
    )


def _group_average_from(averages: dict[int, float]) -> float | None:
    """Mean of a group's per-student overall averages (each student weighted
    equally, not each grade) -- powers the "you vs your class" comparison
    shown alongside rank.
    """
    values = [v for v in averages.values() if v is not None]
    return round(sum(values) / len(values), 2) if values else None


def rank_and_group_average(
    db: Session, student_ids: list[int], student_id: int, quarter: int, school_year: int
) -> tuple[int | None, int, float | None]:
    """Rank position + the group's average in one pass -- build_student_overview
    needs both per scope (class/parallel/school) and they're derived from the
    exact same averages dict, so computing it once instead of twice halves
    the query count for what's otherwise the same data fetched back to back.
    """
    averages = overall_averages_for_students(db, student_ids, quarter, school_year)
    ranked = _ranked_ids(student_ids, averages)
    out_of = len(student_ids)
    try:
        position = ranked.index(student_id) + 1
    except ValueError:
        position = None
    return position, out_of, _group_average_from(averages)


def leaderboard(db: Session, student_ids: list[int], quarter: int, school_year: int) -> list[dict]:
    if not student_ids:
        return []
    averages = overall_averages_for_students(db, student_ids, quarter, school_year)
    students = {s.id: s for s in db.query(Student).filter(Student.id.in_(student_ids)).all()}
    class_ids = {s.class_id for s in students.values() if s.class_id is not None}
    class_names = {c.id: c.name for c in db.query(Class).filter(Class.id.in_(class_ids)).all()}
    ranked = _ranked_ids(student_ids, averages)

    result = []
    for position, student_id in enumerate(ranked, start=1):
        student = students.get(student_id)
        if not student:
            continue
        result.append({
            "student_id": student_id,
            "first_name": student.first_name,
            "last_name": student.last_name,
            "class_id": student.class_id,
            "class_name": class_names.get(student.class_id),
            "overall_average": averages.get(student_id),
            "position": position,
            "out_of": len(student_ids),
        })
    return result


def class_student_ids(db: Session, class_id: int) -> list[int]:
    rows = db.query(Student.id).filter(
        Student.class_id == class_id,
        Student.is_active == True,
    ).all()
    return [row[0] for row in rows]


def parallel_student_ids(db: Session, school_id: int | None, grade: int) -> list[int]:
    class_ids = [
        row[0] for row in db.query(Class.id).filter(
            Class.school_id == school_id,
            Class.grade == grade,
        ).all()
    ]
    if not class_ids:
        return []
    rows = db.query(Student.id).filter(
        Student.class_id.in_(class_ids),
        Student.is_active == True,
    ).all()
    return [row[0] for row in rows]


def school_student_ids(db: Session, school_id: int | None) -> list[int]:
    rows = db.query(Student.id).filter(
        Student.school_id == school_id,
        Student.is_active == True,
    ).all()
    return [row[0] for row in rows]


def bottom_performers(db: Session, student_ids: list[int], quarter: int, school_year: int, limit: int = 15) -> list[dict]:
    """Same shape as leaderboard(), worst-first -- the low end of the same
    ranking a director/teacher already sees, surfaced separately so they
    don't have to scroll a whole school's leaderboard to find who needs help.

    Reversing the full leaderboard would put not-yet-graded students (who
    leaderboard() ranks *last*, deliberately not conflated with a real 0 --
    see _ranked_ids) at the *top* of this list instead of the students who
    are actually struggling. Filter those out first.
    """
    board = leaderboard(db, student_ids, quarter, school_year)
    graded = [entry for entry in board if entry["overall_average"] is not None]
    return list(reversed(graded))[:limit]


def biggest_decliners(db: Session, student_ids: list[int], quarter: int, school_year: int, limit: int = 15) -> list[dict]:
    """Students whose overall average dropped the most from the previous
    quarter to this one. A student missing a grade in either quarter is
    excluded -- there's nothing to compare, and treating a missing grade as
    0 would falsely flag "never graded yet" as "collapsed".

    quarter <= 1 is rejected rather than wrapping to quarter 4 of the
    previous school year -- that comparison would need a *different*
    school_year for the "previous" side, which this function isn't set up
    to resolve, and a chorak-1-vs-summer-break comparison isn't
    meaningful anyway.
    """
    if quarter <= 1:
        return []

    current = overall_averages_for_students(db, student_ids, quarter, school_year)
    previous = overall_averages_for_students(db, student_ids, quarter - 1, school_year)
    students = {s.id: s for s in db.query(Student).filter(Student.id.in_(student_ids)).all()}

    # Which class each flagged student is in: in a school of any size a bare
    # name isn't enough for staff to place the pupil, so the class travels
    # with every row here the same way it already does on the leaderboard.
    class_names = {
        row.id: row.name
        for row in db.query(Class).filter(
            Class.id.in_({s.class_id for s in students.values() if s.class_id})
        ).all()
    }

    deltas = []
    for student_id in student_ids:
        cur = current.get(student_id)
        prev = previous.get(student_id)
        if cur is None or prev is None:
            continue
        deltas.append((student_id, cur, prev))
    deltas.sort(key=lambda item: item[1] - item[2])

    result = []
    for student_id, cur, prev in deltas[:limit]:
        student = students.get(student_id)
        if not student:
            continue
        result.append({
            "student_id": student_id,
            "first_name": student.first_name,
            "last_name": student.last_name,
            "class_name": class_names.get(student.class_id),
            "current_average": cur,
            "previous_average": prev,
            "delta": round(cur - prev, 2),
        })
    return result


def quarterly_trend(db: Session, student_id: int, up_to_quarter: int, school_year: int) -> list[dict]:
    """Overall average for each quarter from 1 through up_to_quarter within
    the given school year, computed fresh from Grade rows every call rather
    than stored as snapshots -- Grade.quarter/school_year already makes this
    a cheap per-student query (a handful of indexed rows per quarter), so a
    history table would just be a second source of truth to keep in sync
    for no real benefit.
    """
    return [
        {"quarter": q, "overall_average": overall_average(db, student_id, q, school_year)}
        for q in range(1, up_to_quarter + 1)
    ]


def build_student_overview(
    db: Session, student: Student, quarter: int | None = None, school_year: int | None = None
) -> dict:
    """The full per-student analytics payload -- shared by the /analytics
    router (director/teacher/parent reading live) and the sync pusher (which
    snapshots this same shape to the Public Server so parents can read it
    there too, since ranking needs the whole class/parallel/school roster
    that the Public Server never has a complete copy of).
    """
    quarter = quarter or current_quarter()
    school_year = school_year if school_year is not None else current_school_year()

    subject_rows = subject_averages(db, student.id, quarter, school_year)
    subject_breakdown = sorted(
        (
            {"subject": subject, "average": avg, "grade_count": count}
            for subject, avg, count in subject_rows
        ),
        key=lambda entry: entry["average"],
        reverse=True,
    )

    school_class = db.query(Class).filter(Class.id == student.class_id).first() if student.class_id else None

    class_ids = class_student_ids(db, student.class_id) if student.class_id else []
    parallel_ids = (
        parallel_student_ids(db, student.school_id, school_class.grade)
        if school_class is not None and school_class.grade is not None
        else []
    )
    school_ids = school_student_ids(db, student.school_id) if student.school_id else []

    class_pos, class_out, class_avg = rank_and_group_average(db, class_ids, student.id, quarter, school_year)
    parallel_pos, parallel_out, parallel_avg = rank_and_group_average(db, parallel_ids, student.id, quarter, school_year)
    school_pos, school_out, school_avg = rank_and_group_average(db, school_ids, student.id, quarter, school_year)

    return {
        "student_id": student.id,
        "first_name": student.first_name,
        "last_name": student.last_name,
        "quarter": quarter,
        "school_year": school_year,
        "overall_average": overall_average(db, student.id, quarter, school_year),
        "class_rank": {"position": class_pos, "out_of": class_out},
        "parallel_rank": {"position": parallel_pos, "out_of": parallel_out},
        "school_rank": {"position": school_pos, "out_of": school_out},
        "class_average": class_avg,
        "parallel_average": parallel_avg,
        "school_average": school_avg,
        "subject_breakdown": subject_breakdown,
        "strongest_subject": subject_breakdown[0]["subject"] if subject_breakdown else None,
        "weakest_subject": subject_breakdown[-1]["subject"] if len(subject_breakdown) > 1 else None,
        "lesson_attendance_rate": lesson_attendance_rate(db, student.id, quarter, school_year),
        "trend": quarterly_trend(db, student.id, quarter, school_year),
    }


def lesson_attendance_rate(db: Session, student_id: int, quarter: int, school_year: int) -> float | None:
    since, until = quarter_date_range(quarter, school_year)
    rows = db.query(LessonAttendance.status).filter(
        LessonAttendance.student_id == student_id,
        LessonAttendance.attendance_date >= since,
        LessonAttendance.attendance_date <= until,
    ).all()
    if not rows:
        return None
    present = sum(1 for (status,) in rows if status in ("present", "late"))
    return round(present / len(rows) * 100, 1)
