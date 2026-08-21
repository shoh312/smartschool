from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class AnnouncementCreate(BaseModel):
    title: str
    body: str
    class_id: Optional[int] = None


class AnnouncementResponse(BaseModel):
    id: int
    school_id: int
    class_id: Optional[int] = None
    title: str
    body: str
    created_at: datetime

    class Config:
        from_attributes = True
