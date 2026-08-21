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
    # Nullable: a pupil signs in for themselves now, and plenty of them
    # have no parent phone on file. Requiring one here meant their account
    # never reached this server at all, so they could log in on the school
    # network and nowhere else -- which is the one place they never are.
    parent_id = Column(Integer, ForeignKey("parents.id"), nullable=True, index=True)
    is_active = Column(Boolean, default=True, nullable=False)

    # Optional -- synced from the local server only when the director has
    # enabled this student to log in on their own (see local
    # app/utils/security.py::hash_student_password for the hashing scheme;
    # this server only ever stores/compares the hash, never the plaintext).
    username = Column(String, unique=True, nullable=True, index=True)
    password_hash = Column(String, nullable=True)
    password_salt = Column(String, nullable=True)

    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

    parent = relationship("Parent", back_populates="students")
