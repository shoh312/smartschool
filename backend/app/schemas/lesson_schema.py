from typing import Optional

from pydantic import BaseModel, Field


class LessonCreate(BaseModel):
    class_id: int
    subject: str
    day_of_week: int = Field(ge=0, le=6)
    start_time: str
    duration_minutes: int = 45
    teacher_id: Optional[int] = None
    room: Optional[str] = None


class LessonUpdate(BaseModel):
    subject: Optional[str] = None
    day_of_week: Optional[int] = Field(default=None, ge=0, le=6)
    start_time: Optional[str] = None
    duration_minutes: Optional[int] = None
    teacher_id: Optional[int] = None
    room: Optional[str] = None


class LessonResponse(BaseModel):
    id: int
    class_id: int
    subject: str
    day_of_week: int
    start_time: str
    duration_minutes: int
    teacher_id: Optional[int] = None
    room: Optional[str] = None
    teacher_name: Optional[str] = None

    class Config:
        from_attributes = True


class DiaryEntryOut(BaseModel):
    lesson_id: int
    subject: str
    start_time: str
    duration_minutes: int
    room: Optional[str] = None
    teacher_id: Optional[int] = None
    teacher_name: Optional[str] = None
    homework: Optional[str] = None
    teacher_comment: Optional[str] = None
    # Only filled when the diary is requested for one specific student --
    # a class-wide read has no single grade to report.
    grade: Optional[int] = None


class DiaryLogUpdate(BaseModel):
    homework: Optional[str] = None
    teacher_comment: Optional[str] = None


class LessonRosterEntry(BaseModel):
    student_id: int
    first_name: str
    last_name: str
    status: str


class LessonStatusEntry(BaseModel):
    lesson_id: int
    subject: str
    start_time: str
    duration_minutes: int
    students: list[LessonRosterEntry]
