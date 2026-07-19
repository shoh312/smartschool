from sqlalchemy import (
    Column,
    Integer,
    String,
    Boolean,
    ForeignKey,
    TIMESTAMP,
    UniqueConstraint,
)
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.database import Base


class Student(Base):
    __tablename__ = "students"
    __table_args__ = (
        # The idempotency/retry-safety key: a retried sync push for the same
        # local student upserts this row instead of duplicating it.
        UniqueConstraint("school_id", "local_student_id", name="uq_student_school_local_id"),
    )

    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("schools.id"), nullable=False, index=True)
    local_student_id = Column(Integer, nullable=False)
    first_name = Column(String, nullable=False)
    last_name = Column(String, nullable=False)
    # Denormalized snapshot from the local server -- refreshes on the next
    # sync event for this student, not a live join to a Class table.
    class_name = Column(String)
    local_class_id = Column(Integer)
    parent_id = Column(Integer, ForeignKey("parents.id"), nullable=False, index=True)
    is_active = Column(Boolean, default=True, nullable=False)
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

    parent = relationship("Parent", back_populates="students")
