from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel


class AttendanceResponse(BaseModel):
    id: int
    student_id: int
    camera_id: Optional[int] = None
    status: str
    confidence: Optional[float] = None
    attendance_date: date
    time_in: Optional[datetime] = None
    time_out: Optional[datetime] = None
    last_seen: Optional[datetime] = None
    detected_at: Optional[datetime] = None

    class Config:
        from_attributes = True
