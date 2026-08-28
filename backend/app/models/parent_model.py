from sqlalchemy import Column, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.database import Base

class Parent(Base):

    __tablename__ = "parents"

    id = Column(Integer, primary_key=True, index=True)

    school_id = Column(Integer, ForeignKey("schools.id"), index=True)

    full_name = Column(String)

    phone = Column(String)

    # The parent signs in against the Public Server, not here. These are
    # kept so the hash can be generated on the machine that also sends the
    # SMS -- the plaintext must never travel through the sync outbox -- and
    # then carried down with the rest of the parent's data.
    password_hash = Column(String)
    password_salt = Column(String)

    telegram_id = Column(String)

    firebase_token = Column(String)

    students = relationship("Student", backref="parent")
    notifications = relationship("NotificationEvent", back_populates="parent", cascade="all, delete-orphan")
    device_tokens = relationship("DeviceToken", back_populates="parent", cascade="all, delete-orphan")
