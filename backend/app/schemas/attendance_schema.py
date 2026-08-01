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
