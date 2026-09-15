from datetime import datetime

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_school
from app.models.material_model import MaterialAssignment, MaterialAttempt
from app.models.school_model import School
from app.models.student_model import Student
from app.schemas.material_schema import AttemptAckRequest, AttemptSyncRow
from app.schemas.sync_schema import SyncEvent
from app.services.sync_ingest_service import apply_sync_event

router = APIRouter(prefix="/sync", tags=["sync"])


@router.post("/events")
def ingest_sync_event(
    event: SyncEvent,
    db: Session = Depends(get_db),
    school: School = Depends(get_current_school),
):
    apply_sync_event(db, school, event)
    return {"message": "applied"}


@router.get("/attempts", response_model=list[AttemptSyncRow])
def pending_attempts(
    limit: int = 200,
    db: Session = Depends(get_db),
    school: School = Depends(get_current_school),
):
    rows = (
        db.query(MaterialAttempt, MaterialAssignment, Student)
        .join(MaterialAssignment, MaterialAssignment.id == MaterialAttempt.assignment_id)
        .join(Student, Student.id == MaterialAttempt.student_id)
        .filter(
            MaterialAssignment.school_id == school.id,
            MaterialAttempt.submitted_at.isnot(None),
            MaterialAttempt.pulled_at.is_(None),
        )
        .order_by(MaterialAttempt.id.asc())
        .limit(max(1, min(limit, 500)))
        .all()
    )
    return [
        AttemptSyncRow(
            public_id=attempt.id,
            local_assignment_id=assignment.local_assignment_id,
            local_student_id=student.local_student_id,
            attempt_no=attempt.attempt_no,
            started_at=attempt.started_at,
            submitted_at=attempt.submitted_at,
            score=attempt.score,
            max_score=attempt.max_score,
            answers=attempt.answers,
        )
        for attempt, assignment, student in rows
    ]


@router.post("/attempts/ack")
def acknowledge_attempts(
    payload: AttemptAckRequest,
    db: Session = Depends(get_db),
    school: School = Depends(get_current_school),
):
    now = datetime.utcnow()
    updated = (
        db.query(MaterialAttempt)
        .filter(
            MaterialAttempt.id.in_(payload.public_ids),
            MaterialAttempt.pulled_at.is_(None),
            MaterialAttempt.assignment_id.in_(
                db.query(MaterialAssignment.id).filter(MaterialAssignment.school_id == school.id)
            ),
        )
        .all()
    )
    for attempt in updated:
        attempt.pulled_at = now
    db.commit()
    return {"acknowledged": len(updated)}
