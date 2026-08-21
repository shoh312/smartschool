from sqlalchemy import Column, Date, ForeignKey, Integer, String, Text, TIMESTAMP, UniqueConstraint
from sqlalchemy.sql import func

from app.database import Base


class DiaryEntry(Base):
    """One resolved lesson-occurrence for a class/day, synced from the local
    server. Not per-student: the content is identical for every student in
    `local_class_id`, so it's stored once per (school, lesson, date) even
    though the local server fans the sync event out once per student --
    this upserts by that natural key instead of duplicating a row per
    student. Parent reads join through their own synced Student.local_class_id.
    """

    __tablename__ = "diary_entries"
    __table_args__ = (
        UniqueConstraint("school_id", "local_lesson_id", "log_date", name="uq_diary_school_lesson_date"),
    )

    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("schools.id"), nullable=False, index=True)
    local_class_id = Column(Integer, nullable=False, index=True)
    local_lesson_id = Column(Integer, nullable=False, index=True)

    subject = Column(String, nullable=False)
    room = Column(String, nullable=True)
    teacher_name = Column(String, nullable=True)
    day_of_week = Column(Integer, nullable=False)
    start_time = Column(String, nullable=False)
    duration_minutes = Column(Integer, nullable=False)

    log_date = Column(Date, nullable=False, index=True)
    homework = Column(Text, nullable=True)
    teacher_comment = Column(Text, nullable=True)

    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())
