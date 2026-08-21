from fastapi import APIRouter, Depends
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import PublicAuthActor, get_current_actor, get_owned_student
from app.models.calendar_event_model import CalendarEvent
from app.schemas.calendar_schema import CalendarEventResponse

router = APIRouter(prefix="/calendar", tags=["calendar"])


@router.get("/events", response_model=list[CalendarEventResponse])
def student_calendar(
    student_id: int,
    db: Session = Depends(get_db),
    actor: PublicAuthActor = Depends(get_current_actor),
):
    student = get_owned_student(student_id, db, actor)

    return db.query(CalendarEvent).filter(
        CalendarEvent.school_id == student.school_id,
        or_(
            CalendarEvent.local_class_id.is_(None),
            CalendarEvent.local_class_id == student.local_class_id,
        ),
    ).order_by(CalendarEvent.start_date.asc()).all()
