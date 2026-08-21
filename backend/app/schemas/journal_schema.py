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
    quarter: Optional[int] = Field(default=None, ge=1, le=4)


class GradeUpdate(BaseModel):
    value: Optional[int] = Field(default=None, ge=1, le=10)
    comment: Optional[str] = None
    grade_date: Optional[date] = None
    quarter: Optional[int] = Field(default=None, ge=1, le=4)


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
    quarter: Optional[int] = None
    school_year: Optional[int] = None

    class Config:
        from_attributes = True
