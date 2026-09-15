from sqlalchemy import Column, Date, ForeignKey, Integer, String, Text, TIMESTAMP, UniqueConstraint
from sqlalchemy.sql import func

from app.database import Base


class DiaryEntry(Base):

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
