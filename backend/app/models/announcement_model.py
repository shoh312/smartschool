from sqlalchemy import Column, ForeignKey, Integer, String, Text, TIMESTAMP
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.database import Base


class Announcement(Base):
    """A director's post to teachers/parents (e.g. "Payshanba kuni yig'ilish").
    `class_id` null means it targets the whole school; set, only that class.
    """

    __tablename__ = "announcements"

    id = Column(Integer, primary_key=True, index=True)

    school_id = Column(Integer, ForeignKey("schools.id"), nullable=False, index=True)

    class_id = Column(Integer, ForeignKey("classes.id"), nullable=True, index=True)

    title = Column(String, nullable=False)

    body = Column(Text, nullable=False)

    created_by_director_id = Column(Integer, ForeignKey("directors.id"), nullable=True)

    created_at = Column(TIMESTAMP, server_default=func.now())

    school_class = relationship("Class")
