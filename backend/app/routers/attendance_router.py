from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import AuthActor, get_current_actor, get_current_director, get_current_superadmin
from app.models.attendance_model import Attendance
from app.models.director_model import Director
from app.models.student import Student
from app.models.class_model import Class
from app.schemas.attendance_schema import (
    AttendanceResponse,
    DailyAttendanceRecord,
    LiveAttendanceStatus,
    MonthlyClassReport,
    MonthlyStudentSummary,
    StudentAttendanceSummary,
)
from app.services.attendance_service import (
    attendance_history,
    mark_absent_students,
    mark_left_school_students,
)

router = APIRouter(prefix="/attendance", tags=["attendance"])


@router.get("/history", response_model=list[AttendanceResponse])
def get_attendance_history(
    student_id: int | None = None,
    parent_id: int | None = None,
    limit: int = 100,
    db: Session = Depends(get_db),
    actor: AuthActor = Depends(get_current_actor),
):
    school_id = None
    parent_ids = None
    if actor.role == "parent":
        if student_id is not None:
            student = db.query(Student).filter(Student.id == student_id).first()
            if not student or student.parent_id not in actor.parent_ids:
                raise HTTPException(status_code=403, detail="Not your student")
        # `parent_id` (singular) stays in the function signature for the
        # existing query-param contract, but a parent may have a sibling
        # Parent row at another school -- fetch across the whole family, not
        # just this one row.
        parent_ids = actor.parent_ids
    else:
        school_id = actor.director.school_id

    return attendance_history(
        db,
        student_id=student_id,
        parent_ids=parent_ids,
        school_id=school_id,
        limit=limit,
    )


@router.get(
    "/live-status",
    response_model=list[LiveAttendanceStatus],
)
def live_attendance_status(
    class_id: int | None = None,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    today = date.today()
    query = db.query(Student, Attendance).outerjoin(
        Attendance,
        (Attendance.student_id == Student.id)
        & (Attendance.attendance_date == today),
    ).filter(Student.is_active == True, Student.school_id == director.school_id)

    if class_id is not None:
        query = query.filter(Student.class_id == class_id)

    response = []
    for student, attendance in query.all():
        response.append(
            LiveAttendanceStatus(
                student_id=student.id,
                first_name=student.first_name,
                last_name=student.last_name,
                status=attendance.status if attendance else "not_detected",
                attendance_date=today,
                time_in=attendance.time_in if attendance else None,
                time_out=attendance.time_out if attendance else None,
                last_seen=attendance.last_seen if attendance else None,
                camera_id=attendance.camera_id if attendance else None,
            )
        )
    return response


_DAY_MAP = {"mon": 0, "tue": 1, "wed": 2, "thu": 3, "fri": 4, "sat": 5}


def _day_hours(timetable: dict, d: date) -> float:
    for day_name, wd in _DAY_MAP.items():
        if d.weekday() == wd:
            entries = timetable.get(day_name, [])
            if not entries:
                return 6
            return sum(e.get("duration_minutes", 45) for e in entries) / 60.0
    return 6


def _student_attendance_summary(
    db: Session,
    student: Student,
    timetable: dict,
    since: date,
    until: date | None = None,
) -> StudentAttendanceSummary:
    query = db.query(Attendance).filter(
        Attendance.student_id == student.id,
        Attendance.attendance_date >= since,
    )
    if until is not None:
        query = query.filter(Attendance.attendance_date <= until)
    rows = query.order_by(Attendance.attendance_date).all()

    total_hours = 0.0
    total_absent_hours = 0.0
    present_days = 0
    absent_days = 0
    late_days = 0
    total_days = len(rows)
    daily_records = []

    for att in rows:
        daily_records.append(DailyAttendanceRecord(
            date=att.attendance_date.isoformat(),
            status=att.status,
        ))
        day_hours = _day_hours(timetable, att.attendance_date)
        if att.status in ("present", "late"):
            if att.time_in and att.time_out:
                hours = (att.time_out - att.time_in).total_seconds() / 3600
                if hours < 0:
                    hours = 0
                total_hours += hours
            else:
                total_hours += day_hours
            if att.status == "present":
                present_days += 1
            else:
                late_days += 1
        elif att.status in ("absent", "left_school"):
            absent_days += 1
            total_absent_hours += day_hours

    attendance_rate = (present_days + late_days) / total_days * 100 if total_days > 0 else 0.0

    # Today is read off the same rows rather than with another query -- it is
    # already in `rows` whenever the range includes today, which the
    # analytics screen's default 30-day window always does.
    today = date.today()
    today_status = next(
        (att.status for att in rows if att.attendance_date == today),
        None,
    )

    return StudentAttendanceSummary(
        student_id=student.id,
        first_name=student.first_name,
        last_name=student.last_name,
        total_present_hours=round(total_hours, 1),
        total_absent_hours=total_absent_hours,
        total_days=total_days,
        present_days=present_days,
        absent_days=absent_days,
        late_days=late_days,
        attendance_rate=round(attendance_rate, 1),
        daily_records=daily_records,
        today_status=today_status,
    )


@router.get("/class-analytics/{class_id}", response_model=list[StudentAttendanceSummary])
def class_attendance_analytics(
    class_id: int,
    days: int = 30,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    from datetime import timedelta

    school_class = db.query(Class).filter(Class.id == class_id, Class.school_id == director.school_id).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Class not found")

    since = date.today() - timedelta(days=days)
    students = db.query(Student).filter(Student.class_id == class_id, Student.is_active == True).all()
    timetable = school_class.timetable or {}

    return [_student_attendance_summary(db, student, timetable, since) for student in students]


@router.get("/monthly-report", response_model=list[MonthlyClassReport])
def monthly_attendance_report(
    year: int,
    month: int,
    class_id: int | None = None,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    from calendar import monthrange

    if month < 1 or month > 12:
        raise HTTPException(status_code=400, detail="Month must be between 1 and 12")

    since = date(year, month, 1)
    until = date(year, month, monthrange(year, month)[1])

    classes_query = db.query(Class).filter(Class.school_id == director.school_id)
    if class_id is not None:
        classes_query = classes_query.filter(Class.id == class_id)
    classes = classes_query.order_by(Class.name.asc()).all()
    if class_id is not None and not classes:
        raise HTTPException(status_code=404, detail="Class not found")

    report = []
    for school_class in classes:
        students = db.query(Student).filter(
            Student.class_id == school_class.id,
            Student.is_active == True,
        ).order_by(Student.first_name.asc()).all()
        timetable = school_class.timetable or {}

        student_summaries = []
        for student in students:
            summary = _student_attendance_summary(db, student, timetable, since, until=until)
            student_summaries.append(MonthlyStudentSummary(
                student_id=summary.student_id,
                first_name=summary.first_name,
                last_name=summary.last_name,
                present_days=summary.present_days,
                late_days=summary.late_days,
                absent_days=summary.absent_days,
                total_present_hours=summary.total_present_hours,
                total_absent_hours=summary.total_absent_hours,
                attendance_rate=summary.attendance_rate,
            ))

        report.append(MonthlyClassReport(
            class_id=school_class.id,
            class_name=school_class.name,
            students=student_summaries,
        ))

    return report


@router.post(
    "/check-absent",
    response_model=list[AttendanceResponse],
    dependencies=[Depends(get_current_superadmin)],
)
def check_absent(db: Session = Depends(get_db)):
    # System-wide maintenance operation (also runs automatically every cycle in
    # the background loop) -- superadmin-only since it touches every school's data.
    return mark_absent_students(db)


@router.post(
    "/check-left-school",
    response_model=list[AttendanceResponse],
    dependencies=[Depends(get_current_superadmin)],
)
def check_left_school(db: Session = Depends(get_db)):
    return mark_left_school_students(db)
