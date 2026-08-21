from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import AuthActor, get_current_actor, get_current_director
from app.models.announcement_model import Announcement
from app.models.class_model import Class
from app.models.director_model import Director
from app.schemas.announcement_schema import AnnouncementCreate, AnnouncementResponse
from app.services.sync_outbox_service import enqueue_announcement_event

router = APIRouter(prefix="/announcements", tags=["announcements"])


def _require_director_or_teacher(actor: AuthActor) -> None:
    if actor.role not in ("director", "teacher"):
        raise HTTPException(status_code=403, detail="Director or teacher access required")


def _actor_school_id(actor: AuthActor) -> int | None:
    return actor.director.school_id if actor.role == "director" else actor.teacher.school_id


@router.post("", response_model=AnnouncementResponse)
def create_announcement(
    payload: AnnouncementCreate,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    if payload.class_id is not None:
        school_class = db.query(Class).filter(
            Class.id == payload.class_id, Class.school_id == director.school_id
        ).first()
        if not school_class:
            raise HTTPException(status_code=404, detail="Class not found")

    announcement = Announcement(
        school_id=director.school_id,
        class_id=payload.class_id,
        title=payload.title,
        body=payload.body,
        created_by_director_id=director.id,
    )
    db.add(announcement)
    db.commit()
    db.refresh(announcement)

    enqueue_announcement_event(db, announcement)
    db.commit()
    return announcement


@router.get("", response_model=list[AnnouncementResponse])
def list_announcements(
    db: Session = Depends(get_db),
    actor: AuthActor = Depends(get_current_actor),
):
    _require_director_or_teacher(actor)
    return db.query(Announcement).filter(
        Announcement.school_id == _actor_school_id(actor)
    ).order_by(Announcement.created_at.desc()).all()


@router.delete("/{announcement_id}", status_code=204)
def delete_announcement(
    announcement_id: int,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    announcement = db.query(Announcement).filter(
        Announcement.id == announcement_id, Announcement.school_id == director.school_id
    ).first()
    if not announcement:
        raise HTTPException(status_code=404, detail="Announcement not found")
    enqueue_announcement_event(db, announcement, operation="delete")
    db.delete(announcement)
    db.commit()
