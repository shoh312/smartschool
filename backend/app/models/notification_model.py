from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, TIMESTAMP
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.database import Base


class NotificationEvent(Base):
    __tablename__ = "notification_events"

    id = Column(Integer, primary_key=True, index=True)
    parent_id = Column(Integer, ForeignKey("parents.id"), nullable=True)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=True)
    attendance_id = Column(Integer, ForeignKey("attendance.id"), nullable=True)
    event_type = Column(String, index=True)
    title = Column(String)
    body = Column(String)
    status = Column(String, default="pending", index=True)
    error = Column(String, nullable=True)
    sent_at = Column(TIMESTAMP, nullable=True)
    created_at = Column(TIMESTAMP, server_default=func.now())

    parent = relationship("Parent", back_populates="notifications")
    student = relationship("Student", back_populates="notifications")
    attendance = relationship("Attendance", back_populates="notifications")


class DeviceToken(Base):
    __tablename__ = "device_tokens"

    id = Column(Integer, primary_key=True, index=True)
    parent_id = Column(Integer, ForeignKey("parents.id"), index=True)
    token = Column(String, unique=True, index=True)
    platform = Column(String, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(TIMESTAMP, server_default=func.now())
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

    parent = relationship("Parent", back_populates="device_tokens")
