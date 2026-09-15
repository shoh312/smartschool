from sqlalchemy import Column, Date, ForeignKey, Integer, String, Text, TIMESTAMP
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.database import Base


class SchoolEvent(Base):

    __tablename__ = "school_events"

    id = Column(Integer, primary_key=True, index=True)

    school_id = Column(Integer, ForeignKey("schools.id"), nullable=False, index=True)

    class_id = Column(Integer, ForeignKey("classes.id"), nullable=True, index=True)

    title = Column(String, nullable=False)

    description = Column(Text, nullable=True)

    event_type = Column(String, nullable=False)

    start_date = Column(Date, nullable=False, index=True)

    end_date = Column(Date, nullable=True)

    created_by_director_id = Column(Integer, ForeignKey("directors.id"), nullable=True)

    created_at = Column(TIMESTAMP, server_default=func.now())

    school_class = relationship("Class")
