from sqlalchemy import (
    Column,
    Integer,
    String,
    Float,
    ForeignKey,
    TIMESTAMP
)

from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.database import Base

from sqlalchemy import Date

class Attendance(Base):

    __tablename__ = "attendance"

    id = Column(Integer, primary_key=True)

    student_id = Column(
        Integer,
        ForeignKey("students.id")
    )

    camera_id = Column(
        Integer,
        ForeignKey("cameras.id")
    )

    status = Column(String)

    confidence = Column(Float)

    attendance_date = Column(Date)

    time_in = Column(TIMESTAMP)

    time_out = Column(TIMESTAMP)

    last_seen = Column(TIMESTAMP)

    detected_at = Column(
        TIMESTAMP,
        server_default=func.now()
    )

    created_at = Column(
        TIMESTAMP,
        server_default=func.now()
    )

    updated_at = Column(
        TIMESTAMP,
        server_default=func.now(),
        onupdate=func.now()
    )

    student = relationship("Student", back_populates="attendances")
    camera = relationship("Camera", back_populates="attendances")
    notifications = relationship("NotificationEvent", back_populates="attendance", cascade="all, delete-orphan")
