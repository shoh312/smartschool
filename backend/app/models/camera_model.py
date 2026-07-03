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

    class_id = Column(
        Integer,
        ForeignKey("classes.id")
    )

    name = Column(String)

    ip_address = Column(String)

    rtsp_url = Column(String)

    detection_start_time = Column(String)

    detection_end_time = Column(String)

    detect_duration_seconds = Column(Integer)

    wait_duration_minutes = Column(Integer)

    is_active = Column(
        Boolean,
        default=True
    )

    attendances = relationship("Attendance", back_populates="camera", cascade="all, delete-orphan")
    school_class = relationship("Class", back_populates="cameras")
