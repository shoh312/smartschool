from datetime import date, datetime
from typing import Literal, Optional

from pydantic import BaseModel


class SyncParent(BaseModel):
    phone: str
    full_name: Optional[str] = None


class SyncStudent(BaseModel):
    local_id: int
    first_name: str
    last_name: str
    class_name: Optional[str] = None
    local_class_id: Optional[int] = None
    is_active: bool = True


class SyncGrade(BaseModel):
    local_id: int
    subject: str
    value: int
    comment: Optional[str] = None
    grade_date: date
    teacher_name: Optional[str] = None
    local_teacher_id: int


class SyncAttendance(BaseModel):
    local_id: int
    status: str
    attendance_date: date
    time_in: Optional[datetime] = None
    time_out: Optional[datetime] = None
    last_seen: Optional[datetime] = None


class SyncEvent(BaseModel):
    """One outbox entry from a local server. Every event is a self-contained
    snapshot -- it always carries the parent + student identity inline, so
    the Public Server can upsert parent -> student -> grade/attendance in one
    transaction regardless of what order events actually arrive in.
    """

    type: Literal["student", "grade", "attendance"]
    operation: Literal["upsert", "delete", "deactivate"] = "upsert"
    parent: SyncParent
    student: SyncStudent
    grade: Optional[SyncGrade] = None
    attendance: Optional[SyncAttendance] = None
