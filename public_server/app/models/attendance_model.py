from sqlalchemy import (
    Column,
    Integer,
    String,
    Date,
    ForeignKey,
    TIMESTAMP,
    UniqueConstraint,
)
from sqlalchemy.sql import func

from app.database import Base


class AttendanceStatus(Base):
    __tablename__ = "attendance_status"
    __table_args__ = (
        UniqueConstraint(
            "school_id", "local_attendance_id", name="uq_attendance_school_local_id"
        ),
    )

    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("schools.id"), nullable=False, index=True)
    local_attendance_id = Column(Integer, nullable=False)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=False, index=True)
    # No camera_id, no confidence, no photo -- only the status a parent needs.
    status = Column(String, nullable=False)
    attendance_date = Column(Date, nullable=False)
    time_in = Column(TIMESTAMP)
    time_out = Column(TIMESTAMP)
    last_seen = Column(TIMESTAMP)
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())
