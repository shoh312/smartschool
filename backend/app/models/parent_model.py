from sqlalchemy import Column, Integer, String
from sqlalchemy.orm import relationship

from app.database import Base

class Parent(Base):

    __tablename__ = "parents"

    id = Column(Integer, primary_key=True, index=True)

    full_name = Column(String)

    phone = Column(String)

    telegram_id = Column(String)

    firebase_token = Column(String)

    students = relationship("Student", backref="parent")
    notifications = relationship("NotificationEvent", back_populates="parent", cascade="all, delete-orphan")
    device_tokens = relationship("DeviceToken", back_populates="parent", cascade="all, delete-orphan")
