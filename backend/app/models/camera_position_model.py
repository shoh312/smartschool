from sqlalchemy import Column, ForeignKey, Integer, String, TIMESTAMP
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.database import Base


class CameraPosition(Base):

    __tablename__ = "camera_positions"

    id = Column(Integer, primary_key=True, index=True)

    camera_id = Column(Integer, ForeignKey("cameras.id", ondelete="CASCADE"), nullable=False, index=True)
    class_id = Column(Integer, ForeignKey("classes.id", ondelete="CASCADE"), nullable=False, index=True)

    subject = Column(String, nullable=True)

    day_of_week = Column(Integer, nullable=True)

    start_time = Column(String, nullable=False)
    end_time = Column(String, nullable=False)

    created_at = Column(TIMESTAMP, server_default=func.now())

    camera = relationship("Camera")
    school_class = relationship("Class")
