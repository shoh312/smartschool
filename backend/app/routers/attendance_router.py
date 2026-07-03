from datetime import date

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.attendance_model import Attendance
from app.models.student import Student
from app.schemas.attendance_schema import AttendanceResponse, LiveAttendanceStatus
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
):
    return attendance_history(
        db,
        student_id=student_id,
        parent_id=parent_id,
        limit=limit,
    )


@router.get("/live-status", response_model=list[LiveAttendanceStatus])
def live_attendance_status(
    class_id: int | None = None,
    db: Session = Depends(get_db),
):
    today = date.today()
    query = db.query(Student, Attendance).outerjoin(
        Attendance,
        (Attendance.student_id == Student.id)
        & (Attendance.attendance_date == today),
    ).filter(Student.is_active == True)

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


@router.post("/check-absent", response_model=list[AttendanceResponse])
def check_absent(db: Session = Depends(get_db)):
    return mark_absent_students(db)


@router.post("/check-left-school", response_model=list[AttendanceResponse])
def check_left_school(db: Session = Depends(get_db)):
    return mark_left_school_students(db)
