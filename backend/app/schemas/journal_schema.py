from datetime import date
from typing import Optional

from pydantic import BaseModel, Field


class GradeCreate(BaseModel):
    student_id: int
    class_id: int
    subject: str
    value: int = Field(ge=1, le=10)
    comment: Optional[str] = None
    grade_date: Optional[date] = None


class GradeUpdate(BaseModel):
    value: Optional[int] = Field(default=None, ge=1, le=10)
    comment: Optional[str] = None
    grade_date: Optional[date] = None


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
