from sqlalchemy import Column, Date, ForeignKey, Integer, Text, TIMESTAMP, UniqueConstraint
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.database import Base


class LessonLog(Base):
    """The diary/ruznoma entry for one lesson *occurrence* -- homework and a
    teacher's note for a specific date, as opposed to `Lesson` which is just
    the recurring weekly template. One row per (lesson, date), created only
    once a teacher actually writes something.
    """

    __tablename__ = "lesson_logs"
    __table_args__ = (UniqueConstraint("lesson_id", "log_date", name="uq_lesson_logs_lesson_date"),)

    id = Column(Integer, primary_key=True, index=True)

    lesson_id = Column(Integer, ForeignKey("lessons.id"), nullable=False, index=True)

    log_date = Column(Date, nullable=False, index=True)

    homework = Column(Text, nullable=True)

    teacher_comment = Column(Text, nullable=True)

    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

    lesson = relationship("Lesson")
