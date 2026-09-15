from sqlalchemy import Column, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.database import Base


class Lesson(Base):

    __tablename__ = "lessons"

    id = Column(Integer, primary_key=True, index=True)

    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False, index=True)

    subject = Column(String, nullable=False)

    day_of_week = Column(Integer, nullable=False)

    start_time = Column(String, nullable=False)

    duration_minutes = Column(Integer, nullable=False, default=45)

    position_id = Column(Integer, ForeignKey("camera_positions.id", ondelete="CASCADE"), nullable=True, index=True)

    teacher_id = Column(Integer, ForeignKey("teachers.id"), nullable=True)

    room = Column(String, nullable=True)

    school_class = relationship("Class")
    teacher = relationship("Teacher")

    @property
    def teacher_name(self) -> str | None:
        return self.teacher.full_name if self.teacher else None
