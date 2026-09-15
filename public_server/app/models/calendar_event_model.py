from sqlalchemy import Column, Date, ForeignKey, Integer, String, Text, TIMESTAMP, UniqueConstraint
from sqlalchemy.sql import func

from app.database import Base


class CalendarEvent(Base):

    __tablename__ = "calendar_events"
    __table_args__ = (
        UniqueConstraint("school_id", "local_event_id", name="uq_calendar_school_local_id"),
    )

    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("schools.id"), nullable=False, index=True)
    local_event_id = Column(Integer, nullable=False, index=True)
    local_class_id = Column(Integer, nullable=True, index=True)

    title = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    event_type = Column(String, nullable=False)
    start_date = Column(Date, nullable=False, index=True)
    end_date = Column(Date, nullable=True)

    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())
