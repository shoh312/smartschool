from datetime import date
from typing import Optional

from pydantic import BaseModel


class CalendarEventResponse(BaseModel):
    id: int
    title: str
    description: Optional[str] = None
    event_type: str
    start_date: date
    end_date: Optional[date] = None

    class Config:
        from_attributes = True
