from sqlalchemy import Column, Float, ForeignKey, Integer, JSON, String, TIMESTAMP, UniqueConstraint
from sqlalchemy.sql import func

from app.database import Base


class StudentAnalytics(Base):
    """A snapshot of one student's ranking/analytics for one quarter, pushed
    by the local server (see local app/services/sync_outbox_service.py ->
    enqueue_student_analytics_event). Computed there, not here: ranking needs
    the whole class/parallel/school roster, which this server never has a
    complete copy of (it only ever receives one child's own data per sync
    event) -- so unlike grades/attendance, this can't be derived locally.
    """

    __tablename__ = "student_analytics"
    __table_args__ = (
        # school_year disambiguates "quarter 1" across different years --
        # without it here, a new school year's Q1 snapshot would silently
        # overwrite last year's Q1 row instead of creating a new one (same
        # bug the local server's Grade.school_year column exists to avoid).
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
