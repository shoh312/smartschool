from sqlalchemy import Column, Date, ForeignKey, Integer, String, Text, TIMESTAMP
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.database import Base


class Grade(Base):

    __tablename__ = "grades"

    id = Column(Integer, primary_key=True, index=True)

    student_id = Column(Integer, ForeignKey("students.id"), nullable=False, index=True)

    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False, index=True)

    teacher_id = Column(Integer, ForeignKey("teachers.id"), nullable=False, index=True)

    subject = Column(String, nullable=False)

    value = Column(Integer, nullable=False)

    comment = Column(Text)

    grade_date = Column(Date, nullable=False, server_default=func.current_date())

    created_at = Column(TIMESTAMP, server_default=func.now())

    student = relationship("Student")
    school_class = relationship("Class")
    teacher = relationship("Teacher")


class Homework(Base):

    __tablename__ = "homework"

    id = Column(Integer, primary_key=True, index=True)

    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False, index=True)

    teacher_id = Column(Integer, ForeignKey("teachers.id"), nullable=False, index=True)

    subject = Column(String, nullable=False)

    description = Column(Text, nullable=False)

    due_date = Column(Date)

    created_at = Column(TIMESTAMP, server_default=func.now())

    school_class = relationship("Class")
    teacher = relationship("Teacher")
