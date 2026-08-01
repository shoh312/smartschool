from sqlalchemy import (
    Column,
    Integer,
    String,
    Boolean,
    ForeignKey
)
from sqlalchemy.orm import relationship

from app.database import Base

class Camera(Base):

    __tablename__ = "cameras"

    id = Column(Integer, primary_key=True)

    school_id = Column(Integer, ForeignKey("schools.id"), index=True)

    class_id = Column(Integer, ForeignKey("classes.id"), index=True, nullable=True)

    name = Column(String)

    ip_address = Column(String)

    rtsp_url = Column(String)

    is_active = Column(
        Boolean,
        default=True
    )

    attendances = relationship("Attendance", back_populates="camera", cascade="all, delete-orphan")
    school_class = relationship("Class")
