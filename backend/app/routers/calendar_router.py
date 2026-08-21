from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import AuthActor, get_current_actor, get_current_director
from app.models.class_model import Class
from app.models.director_model import Director
from app.models.school_event_model import SchoolEvent
from app.schemas.calendar_schema import CalendarEventCreate, CalendarEventResponse, CalendarEventUpdate
from app.services.sync_outbox_service import enqueue_calendar_event

router = APIRouter(prefix="/calendar", tags=["calendar"])


def _require_director_or_teacher(actor: AuthActor) -> None:
    if actor.role not in ("director", "teacher"):
        raise HTTPException(status_code=403, detail="Director or teacher access required")


def _actor_school_id(actor: AuthActor) -> int | None:
    return actor.director.school_id if actor.role == "director" else actor.teacher.school_id


def _require_class_in_school(db: Session, class_id: int, school_id: int) -> None:
    school_class = db.query(Class).filter(Class.id == class_id, Class.school_id == school_id).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Class not found")


@router.post("/events", response_model=CalendarEventResponse)
def create_event(
    payload: CalendarEventCreate,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    if payload.class_id is not None:
        _require_class_in_school(db, payload.class_id, director.school_id)

    event = SchoolEvent(
        school_id=director.school_id,
        class_id=payload.class_id,
        title=payload.title,
        description=payload.description,
        event_type=payload.event_type,
        start_date=payload.start_date,
        end_date=payload.end_date,
        created_by_director_id=director.id,
    )
    db.add(event)
    db.commit()
    db.refresh(event)

    enqueue_calendar_event(db, event)
    db.commit()
    return event


@router.get("/events", response_model=list[CalendarEventResponse])
def list_events(
    class_id: int | None = None,
    from_date: date | None = None,
    to_date: date | None = None,
    db: Session = Depends(get_db),
    actor: AuthActor = Depends(get_current_actor),
):
    _require_director_or_teacher(actor)
    query = db.query(SchoolEvent).filter(SchoolEvent.school_id == _actor_school_id(actor))
    if class_id is not None:
        query = query.filter((SchoolEvent.class_id == class_id) | (SchoolEvent.class_id.is_(None)))
    if from_date is not None:
        query = query.filter(SchoolEvent.start_date >= from_date)
    if to_date is not None:
        query = query.filter(SchoolEvent.start_date <= to_date)
    return query.order_by(SchoolEvent.start_date.asc()).all()


@router.patch("/events/{event_id}", response_model=CalendarEventResponse)
def update_event(
    event_id: int,
    payload: CalendarEventUpdate,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    event = db.query(SchoolEvent).filter(
        SchoolEvent.id == event_id, SchoolEvent.school_id == director.school_id
    ).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    if payload.class_id is not None:
        _require_class_in_school(db, payload.class_id, director.school_id)
        event.class_id = payload.class_id
    if payload.title is not None:
        event.title = payload.title
    if payload.description is not None:
        event.description = payload.description
    if payload.event_type is not None:
        event.event_type = payload.event_type
    if payload.start_date is not None:
        event.start_date = payload.start_date
    if payload.end_date is not None:
        event.end_date = payload.end_date
    db.commit()
    db.refresh(event)

    enqueue_calendar_event(db, event)
    db.commit()
    return event


@router.delete("/events/{event_id}", status_code=204)
def delete_event(
    event_id: int,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    event = db.query(SchoolEvent).filter(
        SchoolEvent.id == event_id, SchoolEvent.school_id == director.school_id
    ).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    enqueue_calendar_event(db, event, operation="delete")
    db.delete(event)
    db.commit()
