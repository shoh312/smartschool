from datetime import date
from typing import Optional

from pydantic import BaseModel, Field


class GradeCreate(BaseModel):
    student_id: int
    class_id: int
    subject: str
    value: int = Field(ge=1, le=5)
    comment: Optional[str] = None
    grade_date: Optional[date] = None


class GradeResponse(BaseModel):
    id: int
    student_id: int
    class_id: int
    teacher_id: int
    subject: str
    value: int
    comment: Optional[str] = None
    grade_date: date

    class Config:
        from_attributes = True


class HomeworkCreate(BaseModel):
    class_id: int
    subject: str
    description: str
    due_date: Optional[date] = None


class HomeworkResponse(BaseModel):
    id: int
    class_id: int
    teacher_id: int
    subject: str
    description: str
    due_date: Optional[date] = None

    class Config:
        from_attributes = True
