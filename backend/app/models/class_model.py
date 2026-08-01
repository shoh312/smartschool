from sqlalchemy import Column, ForeignKey, Integer, String, JSON
from sqlalchemy.orm import relationship

from app.database import Base

class Class(Base):

    __tablename__ = "classes"

    id = Column(Integer, primary_key=True, index=True)

    school_id = Column(Integer, ForeignKey("schools.id"), index=True)

    name = Column(String)

    grade = Column(Integer)

    start_time = Column(String, nullable=True)

    end_time = Column(String, nullable=True)

    detect_duration_seconds = Column(Integer, nullable=True)

    wait_duration_minutes = Column(Integer, nullable=True)

    timetable = Column(JSON, nullable=True)

    students = relationship("Student", back_populates="school_class", cascade="all, delete-orphan")
