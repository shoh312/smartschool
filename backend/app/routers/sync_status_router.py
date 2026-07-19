from datetime import datetime

from fastapi import APIRouter, Depends
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_superadmin
from app.models.sync_outbox_model import SyncOutboxEntry

router = APIRouter(
    prefix="/sync",
    tags=["sync"],
    dependencies=[Depends(get_current_superadmin)],
)


@router.get("/status")
def sync_status(db: Session = Depends(get_db)):
    """Makes a stuck outbox queue visible instead of silently invisible --
    if this shows a growing pending count with an old oldest_pending_at, the
    Public Server is unreachable and needs attention.
    """
    pending_count = db.query(func.count(SyncOutboxEntry.id)).filter(
        SyncOutboxEntry.status == "pending"
    ).scalar()

    oldest = db.query(SyncOutboxEntry).filter(
        SyncOutboxEntry.status == "pending"
    ).order_by(SyncOutboxEntry.id.asc()).first()

    last_error_entry = db.query(SyncOutboxEntry).filter(
        SyncOutboxEntry.last_error.isnot(None)
    ).order_by(SyncOutboxEntry.id.desc()).first()

    return {
        "pending_count": pending_count,
        "oldest_pending_created_at": oldest.created_at.isoformat() if oldest else None,
        "oldest_pending_attempts": oldest.attempts if oldest else None,
        "last_error": last_error_entry.last_error if last_error_entry else None,
        "checked_at": datetime.utcnow().isoformat(),
    }
