import re
from typing import Optional

from pydantic import BaseModel, Field, field_validator

# The timetable stores the time as text, and everything downstream parses it
# with int(hh), int(mm). A value that will not parse -- "13.45", "8", "1345"
# -- does not raise anywhere: _parse_start returns None, the lesson is
# skipped, and the result is a lesson visible in the timetable that the
# camera never opens for and absence never counts. Silent, and impossible to
# tell apart from a broken camera. So it is refused at the door instead.
_TIME = re.compile(r"^([01]?\d|2[0-3]):[0-5]\d$")


def _validated_time(value: str) -> str:
    if not _TIME.match(value.strip()):
        raise ValueError("Вақт бояд ба намуди HH:MM бошад, масалан 08:30")
    hours, minutes = value.strip().split(":")
    # Stored zero-padded so "8:00" and "08:00" cannot become two different
    # strings for one time -- the diary sorts these as text.
    return "%02d:%02d" % (int(hours), int(minutes))


class LessonCreate(BaseModel):
    class_id: int
    subject: str
    day_of_week: int = Field(ge=0, le=6)
    start_time: str
    duration_minutes: int = Field(default=45, ge=5, le=240)
    teacher_id: Optional[int] = None
    room: Optional[str] = None

    @field_validator("start_time")
    @classmethod
    def check_start_time(cls, value: str) -> str:
        return _validated_time(value)


class LessonUpdate(BaseModel):
    subject: Optional[str] = None
    day_of_week: Optional[int] = Field(default=None, ge=0, le=6)
    start_time: Optional[str] = None
    duration_minutes: Optional[int] = Field(default=None, ge=5, le=240)
    teacher_id: Optional[int] = None
    room: Optional[str] = None

    @field_validator("start_time")
    @classmethod
    def check_start_time(cls, value: Optional[str]) -> Optional[str]:
        return None if value is None else _validated_time(value)


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
