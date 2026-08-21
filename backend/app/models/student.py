from sqlalchemy import (
    Column,
    Integer,
    String,
    Boolean,
    ForeignKey
)
from sqlalchemy.orm import relationship

from app.database import Base

class Student(Base):

    __tablename__ = "students"

    id = Column(Integer, primary_key=True, index=True)

    school_id = Column(Integer, ForeignKey("schools.id"), index=True)

    class_id = Column(
        Integer,
        ForeignKey("classes.id")
    )

    parent_id = Column(
        Integer,
        ForeignKey("parents.id")
    )

    first_name = Column(String)

    last_name = Column(String)

    photo = Column(String)

    face_encoding = Column(String)

    is_active = Column(Boolean, default=True)

    # Optional -- only set when the director enables this student to log in
    # on their own (Public Server only, same as a parent; see
    # app/utils/security.py::hash_student_password for why this is a plain
    # salted sha256 pair, not the passlib/bcrypt scheme used for
    # director/teacher).
    username = Column(String, unique=True, nullable=True, index=True)
    password_hash = Column(String, nullable=True)
    password_salt = Column(String, nullable=True)

    attendances = relationship("Attendance", back_populates="student", cascade="all, delete-orphan")
    notifications = relationship("NotificationEvent", back_populates="student", cascade="all, delete-orphan")
    school_class = relationship("Class", back_populates="students")