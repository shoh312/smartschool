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


# --------------------------------------------------------------------------
# The one flow that runs the other way: pupils' work going back to school.
#
# Everything else is pushed from the school server to here. Test attempts
# are written here (that's where the pupil is) and have to travel back --
# but the school server sits on a LAN with no inbound route from the
# internet, so *it* does the asking. This endpoint just leaves the finished
# work where the school can come and collect it.
# --------------------------------------------------------------------------

@router.get("/attempts", response_model=list[AttemptSyncRow])
def pending_attempts(
    limit: int = 200,
    db: Session = Depends(get_db),
    school: School = Depends(get_current_school),
):
    """Submitted attempts this school hasn't collected yet.

    Ids are translated back into the school's own (`local_*`) ids here, so
    the puller never has to know about this server's numbering.
    """
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
    """Mark attempts as collected -- called only after the school server has
    committed them, so a failure mid-transfer just means they're handed out
    again next time rather than lost.

    Rows are kept, not deleted: the pupil still needs to see their own past
    results here.
    """
    now = datetime.utcnow()
    updated = (
        db.query(MaterialAttempt)
        .filter(
            MaterialAttempt.id.in_(payload.public_ids),
            MaterialAttempt.pulled_at.is_(None),
            # Scoped to the calling school so one school's key can't touch
            # another's rows.
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
