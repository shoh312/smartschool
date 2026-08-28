from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import PublicAuthActor, get_current_actor, get_current_parent, get_current_school
from app.models.notification_model import DeviceToken, NotificationEvent
from app.models.parent_model import Parent
from app.models.school_model import School
from app.models.student_model import Student
from app.notifications.firebase import create_and_send_notification
from app.schemas.notification_schema import (
    DeviceTokenCreate,
    NotificationResponse,
    SchoolMessageCreate,
)
from app.utils.phone import normalize_phone

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.post("/device-token")
def save_device_token(
    payload: DeviceTokenCreate,
    db: Session = Depends(get_db),
    actor: PublicAuthActor = Depends(get_current_actor),
):
    """Register this device against whoever is signed in on it.

    Pupils get their own login now and their own work to be reminded about,
    so a device can belong to a pupil as well as to a parent. Both fields
    are rewritten on every call: the same handset is often handed between
    them, and the last person to sign in is the one the push should reach.
    """
    is_student = actor.role == "student" and actor.student is not None
    parent_id = actor.parent.id if actor.role == "parent" and actor.parent else None
    student_id = actor.student.id if is_student else None

    device_token = db.query(DeviceToken).filter(DeviceToken.token == payload.token).first()
    if device_token:
        device_token.parent_id = parent_id
        device_token.student_id = student_id
        device_token.platform = payload.platform
        device_token.is_active = True
    else:
        device_token = DeviceToken(
            parent_id=parent_id,
            student_id=student_id,
            token=payload.token,
            platform=payload.platform,
        )
        db.add(device_token)

    db.commit()
    return {"message": "Device token saved"}


@router.post("/school-message")
def school_message(
    payload: SchoolMessageCreate,
    db: Session = Depends(get_db),
    school: School = Depends(get_current_school),
):
    """Lets a school's own server put a message in a parent's app.

    Called directly rather than through the sync outbox on purpose: the
    body carries a pupil's password, and outbox rows are kept after they are
    sent. This way the plaintext exists in one place -- the notification the
    parent is meant to read -- instead of two.

    The parent must already have a child at *this* school, so a leaked
    school key cannot be used to message the whole country.
    """
    normalized = normalize_phone(payload.parent_phone)
    parent = db.query(Parent).filter(Parent.phone == normalized).first()
    if not parent:
        raise HTTPException(status_code=404, detail="parent_not_found")

    belongs = db.query(Student).filter(
        Student.parent_id == parent.id,
        Student.school_id == school.id,
    ).first()
    if not belongs:
        raise HTTPException(status_code=403, detail="not_your_parent")

    event = NotificationEvent(
        parent_id=parent.id,
        school_id=school.id,
        event_type=payload.event_type,
        title=payload.title,
        body=payload.body,
    )
    db.add(event)
    db.flush()
    create_and_send_notification(db, event)
    db.commit()
    return {"status": "delivered", "notification_id": event.id}


@router.get("/parent/{parent_id}", response_model=list[NotificationResponse])
def parent_notifications(
    parent_id: int,
    limit: int = 100,
    db: Session = Depends(get_db),
    parent: Parent = Depends(get_current_parent),
):
    if parent.id != parent_id:
        raise HTTPException(status_code=403, detail="Not your notifications")

    return db.query(NotificationEvent).filter(
        NotificationEvent.parent_id == parent_id,
    ).order_by(NotificationEvent.id.desc()).limit(limit).all()
