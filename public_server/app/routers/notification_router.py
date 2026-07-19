from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_parent
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
    parent: Parent = Depends(get_current_parent),
):
    if parent.id != parent_id:
        raise HTTPException(status_code=403, detail="Not your notifications")

    return db.query(NotificationEvent).filter(
        NotificationEvent.parent_id == parent_id,
    ).order_by(NotificationEvent.id.desc()).limit(limit).all()
