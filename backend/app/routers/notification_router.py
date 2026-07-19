from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import AuthActor, get_current_actor, get_current_parent
from app.models.notification_model import DeviceToken, NotificationEvent
from app.models.parent_model import Parent
from app.schemas.notification_schema import DeviceTokenCreate, NotificationResponse

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.post("/device-token")
def save_device_token(
    payload: DeviceTokenCreate,
    db: Session = Depends(get_db),
    parent: Parent = Depends(get_current_parent),
):
    device_token = db.query(DeviceToken).filter(DeviceToken.token == payload.token).first()
    if device_token:
        device_token.parent_id = parent.id
        device_token.platform = payload.platform
        device_token.is_active = True
    else:
        device_token = DeviceToken(
            parent_id=parent.id,
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
    actor: AuthActor = Depends(get_current_actor),
):
    if actor.role == "parent" and parent_id not in actor.parent_ids:
        raise HTTPException(status_code=403, detail="Not your notifications")

    # A parent with children at multiple schools has a sibling Parent row per
    # school sharing the same phone -- return notifications for all of them,
    # not just the one row `parent_id` happens to name.
    parent_ids = actor.parent_ids if actor.role == "parent" else [parent_id]

    return db.query(NotificationEvent).filter(
        NotificationEvent.parent_id.in_(parent_ids),
    ).order_by(NotificationEvent.id.desc()).limit(limit).all()
