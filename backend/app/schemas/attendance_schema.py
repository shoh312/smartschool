from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel


class DailyAttendanceRecord(BaseModel):
    date: str
    status: str


class AttendanceResponse(BaseModel):
    id: int
    student_id: int
    camera_id: Optional[int] = None
    status: str
    confidence: Optional[float] = None
    attendance_date: date
    time_in: Optional[datetime] = None
    time_out: Optional[datetime] = None
    last_seen: Optional[datetime] = None
    detected_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class LiveAttendanceStatus(BaseModel):
    student_id: int
    first_name: str
    last_name: str
    status: str
    attendance_date: date
    time_in: Optional[datetime] = None
    time_out: Optional[datetime] = None
    last_seen: Optional[datetime] = None
    camera_id: Optional[int] = None


class AttendanceEvent(BaseModel):
    type: str
    attendance: AttendanceResponse


class StudentAttendanceSummary(BaseModel):
    student_id: int
    first_name: str
    last_name: str
    total_present_hours: float
    total_absent_hours: float
    total_days: int
    present_days: int
    absent_days: int
    late_days: int
    attendance_rate: float
    daily_records: list[DailyAttendanceRecord] = []

    # How this student stands *today*, separate from the 30-day history
    # above: "present", "late", "absent", "left_school", or None when the
    # cameras have not reached a verdict yet. The analytics screen colours
    # each student's card from this, so a director sees today's room at a
    # glance instead of only the month's averages.
    today_status: Optional[str] = None


class MonthlyStudentSummary(BaseModel):
    student_id: int
    first_name: str
    last_name: str
    present_days: int
    late_days: int
    absent_days: int
    total_present_hours: float
    total_absent_hours: float
    attendance_rate: float


class MonthlyClassReport(BaseModel):
    class_id: int
    class_name: str
    students: list[MonthlyStudentSummary]
