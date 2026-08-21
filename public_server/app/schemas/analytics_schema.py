from typing import Optional

from pydantic import BaseModel


class SubjectAverage(BaseModel):
    subject: str
    average: float
    grade_count: int


class RankInfo(BaseModel):
    position: Optional[int] = None
    out_of: int


class QuarterPoint(BaseModel):
    quarter: int
    overall_average: Optional[float] = None


class StudentAnalyticsOverview(BaseModel):
    student_id: int
    first_name: str
    last_name: str
    quarter: int
    school_year: Optional[int] = None
    overall_average: Optional[float] = None
    class_rank: RankInfo
    parallel_rank: RankInfo
    school_rank: RankInfo
    class_average: Optional[float] = None
    parallel_average: Optional[float] = None
    school_average: Optional[float] = None
    subject_breakdown: list[SubjectAverage]
    strongest_subject: Optional[str] = None
    weakest_subject: Optional[str] = None
    lesson_attendance_rate: Optional[float] = None
    trend: list[QuarterPoint] = []
    updated_at: Optional[str] = None
