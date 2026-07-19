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

    class Config:
        from_attributes = True
