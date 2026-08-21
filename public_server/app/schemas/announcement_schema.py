from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class AnnouncementResponse(BaseModel):
    id: int
    title: str
    body: str
    created_at_local: Optional[datetime] = None

    class Config:
        from_attributes = True
