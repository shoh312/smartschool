from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class DeviceTokenCreate(BaseModel):
    parent_id: int | None = None
    token: str
    platform: Optional[str] = None


class SchoolMessageCreate(BaseModel):

    parent_phone: str
    title: str
    body: str
    event_type: str = "school_message"


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
