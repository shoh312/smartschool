from datetime import date
from typing import Optional

from pydantic import BaseModel


class DiaryEntryResponse(BaseModel):
    lesson_id: int
    subject: str
    room: Optional[str] = None
    teacher_name: Optional[str] = None
    start_time: str
    duration_minutes: int
    log_date: date
    homework: Optional[str] = None
    teacher_comment: Optional[str] = None
    grade: Optional[int] = None
