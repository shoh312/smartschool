from sqlalchemy import Column, Float, ForeignKey, Integer, JSON, String, TIMESTAMP, UniqueConstraint
from sqlalchemy.sql import func

from app.database import Base


class StudentAnalytics(Base):

    __tablename__ = "student_analytics"
    __table_args__ = (
        UniqueConstraint("student_id", "quarter", "school_year", name="uq_student_analytics_student_quarter_year"),
    )

    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("schools.id"), nullable=False, index=True)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=False, index=True)
    quarter = Column(Integer, nullable=False)
    school_year = Column(Integer, nullable=True)

    overall_average = Column(Float, nullable=True)

    class_rank_position = Column(Integer, nullable=True)
    class_rank_out_of = Column(Integer, nullable=False, default=0)
    parallel_rank_position = Column(Integer, nullable=True)
    parallel_rank_out_of = Column(Integer, nullable=False, default=0)
    school_rank_position = Column(Integer, nullable=True)
    school_rank_out_of = Column(Integer, nullable=False, default=0)

    class_average = Column(Float, nullable=True)
    parallel_average = Column(Float, nullable=True)
    school_average = Column(Float, nullable=True)

    subject_breakdown = Column(JSON, nullable=False, default=list)
    strongest_subject = Column(String, nullable=True)
    weakest_subject = Column(String, nullable=True)
    lesson_attendance_rate = Column(Float, nullable=True)
    trend = Column(JSON, nullable=False, default=list)

    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())
