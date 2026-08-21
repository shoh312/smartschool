from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import PublicAuthActor, get_current_actor, get_owned_student, student_ids_for_actor
from app.models.attendance_model import AttendanceStatus
from app.schemas.attendance_schema import AttendanceResponse

router = APIRouter(prefix="/attendance", tags=["attendance"])


@router.get("/history", response_model=list[AttendanceResponse])
def get_attendance_history(
    student_id: int | None = None,
    limit: int = 100,
    db: Session = Depends(get_db),
    actor: PublicAuthActor = Depends(get_current_actor),
):
    query = db.query(AttendanceStatus).filter(AttendanceStatus.student_id.in_(student_ids_for_actor(db, actor)))

    if student_id is not None:
        get_owned_student(student_id, db, actor)
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
