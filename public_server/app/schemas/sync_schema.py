from datetime import date, datetime
from typing import Any, Literal, Optional

from pydantic import BaseModel, model_validator


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
    username: Optional[str] = None
    password_hash: Optional[str] = None
    password_salt: Optional[str] = None


class SyncGrade(BaseModel):
    local_id: int
    subject: str
    value: int
    comment: Optional[str] = None
    grade_date: date
    teacher_name: Optional[str] = None
    local_teacher_id: int
    quarter: Optional[int] = None


class SyncAttendance(BaseModel):
    local_id: int
    status: str
    attendance_date: date
    time_in: Optional[datetime] = None
    time_out: Optional[datetime] = None
    last_seen: Optional[datetime] = None


class SyncSubjectAverage(BaseModel):
    subject: str
    average: float
    grade_count: int


class SyncQuarterPoint(BaseModel):
    quarter: int
    overall_average: Optional[float] = None


class SyncStudentAnalytics(BaseModel):
    quarter: int
    # Disambiguates "quarter 1" across different years (the year a school
    # year STARTS in -- see local app/utils/academic_calendar.py). Optional
    # only so an in-flight outbox entry queued before this field existed
    # doesn't fail validation; new entries always set it.
    school_year: Optional[int] = None
    overall_average: Optional[float] = None
    class_rank_position: Optional[int] = None
    class_rank_out_of: int = 0
    parallel_rank_position: Optional[int] = None
    parallel_rank_out_of: int = 0
    school_rank_position: Optional[int] = None
    school_rank_out_of: int = 0
    class_average: Optional[float] = None
    parallel_average: Optional[float] = None
    school_average: Optional[float] = None
    subject_breakdown: list[SyncSubjectAverage] = []
    strongest_subject: Optional[str] = None
    weakest_subject: Optional[str] = None
    lesson_attendance_rate: Optional[float] = None
    trend: list[SyncQuarterPoint] = []


class SyncDiary(BaseModel):
    local_lesson_id: int
    subject: str
    room: Optional[str] = None
    teacher_name: Optional[str] = None
    day_of_week: int
    start_time: str
    duration_minutes: int
    log_date: date
    homework: Optional[str] = None
    teacher_comment: Optional[str] = None


class SyncCalendarEvent(BaseModel):
    local_id: int
    local_class_id: Optional[int] = None
    title: str
    description: Optional[str] = None
    event_type: str
    start_date: date
    end_date: Optional[date] = None


class SyncAnnouncement(BaseModel):
    local_id: int
    local_class_id: Optional[int] = None
    title: str
    body: str
    created_at: Optional[datetime] = None


class SyncMaterialBlock(BaseModel):
    local_id: int
    position: int
    block_type: str
    body: str = ""
    question_type: Optional[str] = None
    options: Optional[Any] = None
    # The answer key. Needed here because this server marks the work; it is
    # never included in anything sent to a pupil's device.
    correct: Optional[Any] = None
    points: int = 1


class SyncMaterial(BaseModel):
    local_id: int
    subject: str
    title: str
    description: Optional[str] = None
    teacher_name: Optional[str] = None
    max_score: int = 0
    blocks: list[SyncMaterialBlock] = []


class SyncMaterialAssignment(BaseModel):
    local_id: int
    local_material_id: int
    local_class_id: int
    class_name: Optional[str] = None
    teacher_name: Optional[str] = None
    mode: str = "practice"
    due_at: Optional[datetime] = None
    max_attempts: Optional[int] = None
    published_at: Optional[datetime] = None


class SyncEvent(BaseModel):
    """One outbox entry from a local server. Every event is a self-contained
    snapshot -- it always carries the parent + student identity inline, so
    the Public Server can upsert parent -> student -> grade/attendance/
    analytics in one transaction regardless of what order events actually
    arrive in. `diary`/`calendar_event`/`announcement` are fanned out once
    per affected student by the local server but upsert to a single shared
    row here (not per-student) -- see each model's docstring.

    Materials are the exception that has no parent/student block at all:
    they belong to a class, not a family, and pupils sign in for themselves
    now -- so a pupil with no parent on file must still get their homework.
    """

    type: Literal[
        "student", "grade", "attendance", "student_analytics",
        "diary", "calendar_event", "announcement",
        "material", "material_assignment",
    ]
    operation: Literal["upsert", "delete", "deactivate"] = "upsert"
    parent: Optional[SyncParent] = None
    student: Optional[SyncStudent] = None
    grade: Optional[SyncGrade] = None
    attendance: Optional[SyncAttendance] = None
    student_analytics: Optional[SyncStudentAnalytics] = None
    diary: Optional[SyncDiary] = None
    calendar_event: Optional[SyncCalendarEvent] = None
    announcement: Optional[SyncAnnouncement] = None
    material: Optional[SyncMaterial] = None
    material_assignment: Optional[SyncMaterialAssignment] = None

    @model_validator(mode="after")
    def _identity_required_for_family_events(self):
        # parent/student only became optional so material events could omit
        # them. Every older event type still depends on that identity to
        # resolve which family the row belongs to, and silently dropping one
        # that arrived without it would lose a grade -- so demand it here,
        # where the failure is a loud 422 the outbox will retry.
        if self.type in _CLASS_SCOPED_TYPES:
            return self
        if self.student is None:
            raise ValueError(f"'{self.type}' events must carry a student")
        # A pupil is allowed to have no parent on file -- they sign in for
        # themselves. Everything else still needs the family identity to
        # know whose data it is.
        if self.parent is None and self.type != "student":
            raise ValueError(f"'{self.type}' events must carry a parent")
        return self


_CLASS_SCOPED_TYPES = {"material", "material_assignment"}
