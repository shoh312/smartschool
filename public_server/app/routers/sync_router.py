from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_school
from app.models.school_model import School
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
