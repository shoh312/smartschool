from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class DeviceTokenCreate(BaseModel):
    # parent_id is part of the request shape the existing Flutter client
    # sends, but (matching the local server's existing behavior) the
    # authenticated caller from the bearer token is the actual source of
    # truth -- this field is accepted and ignored, not trusted. Optional
    # because a pupil registering their own phone has no parent id to send.
    parent_id: int | None = None
    token: str
    platform: Optional[str] = None


class NotificationResponse(BaseModel):
    id: int
    parent_id: Optional[int] = None
    student_id: Optional[int] = None
    event_type: str
    title: str
    body: str
    status: str
    sent_at: Optional[datetime] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True
