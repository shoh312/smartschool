from sqlalchemy import (
    Column,
    Integer,
    String,
    Date,
    Text,
    ForeignKey,
    TIMESTAMP,
    UniqueConstraint,
)
from sqlalchemy.sql import func

from app.database import Base


class Grade(Base):
    __tablename__ = "grades"
    __table_args__ = (
        UniqueConstraint("school_id", "local_grade_id", name="uq_grade_school_local_id"),
    )

    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("schools.id"), nullable=False, index=True)
    local_grade_id = Column(Integer, nullable=False)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=False, index=True)
    subject = Column(String, nullable=False)
    quarter = Column(Integer, nullable=True)
    value = Column(Integer, nullable=False)
    comment = Column(Text)
    grade_date = Column(Date, nullable=False)
    teacher_name = Column(String)
    # Opaque, no FK -- the Public Server has no Class/Teacher tables. Carried
    # only so GradeResponse stays shape-compatible with the Flutter model,
    # which reads class_id/teacher_id as non-nullable ints.
    local_class_id = Column(Integer, nullable=False)
    local_teacher_id = Column(Integer, nullable=False)
    created_at = Column(TIMESTAMP, server_default=func.now())
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())
