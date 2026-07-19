from sqlalchemy import Column, Integer, String, TIMESTAMP
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.database import Base


class Parent(Base):
    __tablename__ = "parents"

    id = Column(Integer, primary_key=True, index=True)
    # One global row per phone -- unlike the local (per-school) backend, the
    # Public Server has no reason to scope parents per school: a stat's school
    # is already known from the synced student it belongs to.
    phone = Column(String, unique=True, index=True, nullable=False)
    full_name = Column(String)
    created_at = Column(TIMESTAMP, server_default=func.now())
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

    students = relationship("Student", back_populates="parent")
    device_tokens = relationship(
        "DeviceToken", back_populates="parent", cascade="all, delete-orphan"
    )
