from typing import Optional

from pydantic import BaseModel


class SubjectAverage(BaseModel):
    subject: str
    average: float
    grade_count: int


class ClassSubjectAverage(BaseModel):
    """One subject's standing across a whole class.

    Separate from [SubjectAverage] because of ``student_count``: for one
    pupil that number is always 1 and would be noise, but for a class it is
    what says whether the average covers everybody or a handful.
    """

    subject: str
    average: float
    grade_count: int
    student_count: int


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


class LeaderboardEntry(BaseModel):
    student_id: int
    first_name: str
    last_name: str
    class_id: Optional[int] = None
    class_name: Optional[str] = None
    overall_average: Optional[float] = None
    position: int
    out_of: int


class DeclinerEntry(BaseModel):
    student_id: int
    first_name: str
    last_name: str
    class_name: Optional[str] = None
    current_average: float
    previous_average: float
    delta: float


class NeedsAttentionResponse(BaseModel):
    bottom_performers: list[LeaderboardEntry]
    biggest_decliners: list[DeclinerEntry]
