from sqlalchemy import Boolean, Column, Integer, String, TIMESTAMP, text
from sqlalchemy.sql import func

from app.database import Base


class School(Base):

    __tablename__ = "schools"

    id = Column(Integer, primary_key=True, index=True)

    name = Column(String, nullable=False)

    address = Column(String)

    phone = Column(String)

    is_active = Column(Boolean, default=True)

    live_video_enabled = Column(
        Boolean, default=True, server_default=text("true"), nullable=False
    )

    group_mode = Column(
        Boolean, default=False, server_default=text("false"), nullable=False
    )

    sms_enabled = Column(
        Boolean, default=True, server_default=text("true"), nullable=False
    )

    attendance_notifications_enabled = Column(
        Boolean, default=True, server_default=text("true"), nullable=False
    )

    created_at = Column(TIMESTAMP, server_default=func.now())
