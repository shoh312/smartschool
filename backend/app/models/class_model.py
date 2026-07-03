from sqlalchemy import Column, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.database import Base

class Class(Base):

    __tablename__ = "classes"

    id = Column(Integer, primary_key=True, index=True)

    school_id = Column(Integer, ForeignKey("schools.id"), index=True)

    name = Column(String)

    grade = Column(Integer)

    students = relationship("Student", back_populates="school_class", cascade="all, delete-orphan")
    cameras = relationship("Camera", back_populates="school_class", cascade="all, delete-orphan")
