from sqlalchemy import Column, Date, Float, ForeignKey, Integer, String, TIMESTAMP, UniqueConstraint
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.database import Base


class LessonAttendance(Base):
    """Per-lesson attendance, additive alongside the existing day-level
    `Attendance` table -- that table and everything reading it (live-status,
    class-analytics, monthly-report, parent history) stays untouched. This
    table exists so a student's attendance can be judged per subject/period
    (e.g. absent from Math 3rd period) instead of only once per day.
    """

    __tablename__ = "lesson_attendance"
    __table_args__ = (
        UniqueConstraint("student_id", "lesson_id", "attendance_date", name="uq_lesson_attendance_student_lesson_date"),
    )

    id = Column(Integer, primary_key=True, index=True)

    student_id = Column(Integer, ForeignKey("students.id"), nullable=False, index=True)

    lesson_id = Column(Integer, ForeignKey("lessons.id"), nullable=False, index=True)

    camera_id = Column(Integer, ForeignKey("cameras.id"), nullable=True)

    status = Column(String, nullable=False)

    confidence = Column(Float, nullable=True)

    attendance_date = Column(Date, nullable=False)

    detected_at = Column(TIMESTAMP, server_default=func.now())

    student = relationship("Student")
    lesson = relationship("Lesson")
