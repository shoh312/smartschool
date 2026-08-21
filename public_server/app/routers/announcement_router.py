from fastapi import APIRouter, Depends
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import PublicAuthActor, get_current_actor, get_owned_student
from app.models.announcement_model import Announcement
from app.schemas.announcement_schema import AnnouncementResponse

router = APIRouter(prefix="/announcements", tags=["announcements"])


@router.get("", response_model=list[AnnouncementResponse])
def student_announcements(
    student_id: int,
    db: Session = Depends(get_db),
    actor: PublicAuthActor = Depends(get_current_actor),
):
    student = get_owned_student(student_id, db, actor)

    return db.query(Announcement).filter(
        Announcement.school_id == student.school_id,
        or_(
            Announcement.local_class_id.is_(None),
            Announcement.local_class_id == student.local_class_id,
        ),
    ).order_by(Announcement.created_at_local.desc().nullslast()).all()
