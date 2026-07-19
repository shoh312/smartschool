from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_parent
from app.models.attendance_model import AttendanceStatus
from app.models.parent_model import Parent
from app.models.student_model import Student
from app.schemas.attendance_schema import AttendanceResponse

router = APIRouter(prefix="/attendance", tags=["attendance"])


@router.get("/history", response_model=list[AttendanceResponse])
def get_attendance_history(
    student_id: int | None = None,
    limit: int = 100,
    db: Session = Depends(get_db),
    parent: Parent = Depends(get_current_parent),
):
    query = db.query(AttendanceStatus).join(
        Student, Student.id == AttendanceStatus.student_id
    ).filter(Student.parent_id == parent.id)

    if student_id is not None:
        student = db.query(Student).filter(Student.id == student_id).first()
        if not student or student.parent_id != parent.id:
            raise HTTPException(status_code=403, detail="Not your student")
        query = query.filter(AttendanceStatus.student_id == student_id)

    rows = query.order_by(
        AttendanceStatus.attendance_date.desc(), AttendanceStatus.id.desc()
    ).limit(limit).all()

    return [
        AttendanceResponse(
            id=row.id,
            student_id=row.student_id,
            camera_id=None,
            status=row.status,
            confidence=None,
            attendance_date=row.attendance_date,
            time_in=row.time_in,
            time_out=row.time_out,
            last_seen=row.last_seen,
            detected_at=row.updated_at,
        )
        for row in rows
    ]
