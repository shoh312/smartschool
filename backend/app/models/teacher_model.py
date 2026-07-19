from sqlalchemy import Boolean, Column, ForeignKey, Integer, String, TIMESTAMP
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.database import Base


class Teacher(Base):

    __tablename__ = "teachers"

    id = Column(Integer, primary_key=True, index=True)

    school_id = Column(Integer, ForeignKey("schools.id"), index=True)

    full_name = Column(String, nullable=False)

    subject = Column(String, index=True)

    email = Column(String, unique=True, nullable=False, index=True)

    hashed_password = Column(String, nullable=False)

    is_active = Column(Boolean, default=True)

    created_at = Column(TIMESTAMP, server_default=func.now())

    class_assignments = relationship(
        "TeacherClass", back_populates="teacher", cascade="all, delete-orphan"
    )


class TeacherClass(Base):
    """Which classes a teacher is allowed to enter grades for."""

    __tablename__ = "teacher_classes"

    id = Column(Integer, primary_key=True, index=True)

    teacher_id = Column(Integer, ForeignKey("teachers.id"), nullable=False, index=True)

    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False, index=True)

    subject = Column(String)

    teacher = relationship("Teacher", back_populates="class_assignments")
    school_class = relationship("Class")
