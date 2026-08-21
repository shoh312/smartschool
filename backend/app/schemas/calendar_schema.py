from datetime import date
from typing import Optional

from pydantic import BaseModel


class CalendarEventCreate(BaseModel):
    title: str
    description: Optional[str] = None
    event_type: str
    start_date: date
    end_date: Optional[date] = None
    class_id: Optional[int] = None


class CalendarEventUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    event_type: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    class_id: Optional[int] = None


class CalendarEventResponse(BaseModel):
    id: int
    school_id: int
    class_id: Optional[int] = None
    title: str
    description: Optional[str] = None
    event_type: str
    start_date: date
    end_date: Optional[date] = None

    class Config:
        from_attributes = True
