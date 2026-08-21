from datetime import date
from typing import Optional

from pydantic import BaseModel


class GradeResponse(BaseModel):
    id: int
    student_id: int
    class_id: int
    teacher_id: int
    teacher_name: Optional[str] = None
    subject: str
    value: int
    comment: Optional[str] = None
    grade_date: date
    # Synced from the school server and returned so a pupil's app can scope
    # a day-by-day view to the quarter it is showing, rather than guessing
    # the quarter's date range for itself.
    quarter: Optional[int] = None

    class Config:
        from_attributes = True
