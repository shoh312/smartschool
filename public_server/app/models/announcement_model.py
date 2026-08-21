from sqlalchemy import Column, ForeignKey, Integer, String, Text, TIMESTAMP, UniqueConstraint
from sqlalchemy.sql import func

from app.database import Base


class Announcement(Base):
    """A director's post, synced from the local server. Not per-student --
    upserted by (school_id, local_announcement_id), same dedup reasoning as
    DiaryEntry/CalendarEvent.
    """

    __tablename__ = "announcements"
    __table_args__ = (
        UniqueConstraint("school_id", "local_announcement_id", name="uq_announcement_school_local_id"),
    )

    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("schools.id"), nullable=False, index=True)
    local_announcement_id = Column(Integer, nullable=False, index=True)
    local_class_id = Column(Integer, nullable=True, index=True)

    title = Column(String, nullable=False)
    body = Column(Text, nullable=False)
    created_at_local = Column(TIMESTAMP, nullable=True)

    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())
