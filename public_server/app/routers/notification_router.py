from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import PublicAuthActor, get_current_actor, get_current_parent
from app.models.notification_model import DeviceToken, NotificationEvent
from app.models.parent_model import Parent
from app.schemas.notification_schema import DeviceTokenCreate, NotificationResponse

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
