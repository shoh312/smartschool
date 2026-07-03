from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class DeviceTokenCreate(BaseModel):
    parent_id: int
    token: str
    platform: Optional[str] = None


class NotificationResponse(BaseModel):
    id: int
    parent_id: Optional[int] = None
    student_id: Optional[int] = None
    attendance_id: Optional[int] = None
    event_type: str
    title: str
    body: str
    status: str
    sent_at: Optional[datetime] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True
