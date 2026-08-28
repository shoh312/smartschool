from sqlalchemy import Boolean, Column, Integer, String, TIMESTAMP
from sqlalchemy.sql import func

from app.database import Base


class School(Base):

    __tablename__ = "schools"

    id = Column(Integer, primary_key=True, index=True)

    name = Column(String, nullable=False)

    address = Column(String)

    phone = Column(String)

    is_active = Column(Boolean, default=True)

    # Two switches the director owns, because both change what everyone
    # else in the school sees.
    #
    # A school that only wants attendance has no use for a live picture, and
    # a camera pointed at a classroom is not something to leave watchable by
    # default -- so it can be turned off for the whole school at once.
    live_video_enabled = Column(Boolean, default=True, nullable=False)

    # Academies run several groups through one room in a day; ordinary
    # schools give each class its own room. With this off a camera belongs
    # to one class, as it always has; with it on the camera belongs to the
    # room and the timetable decides whose lesson is in front of it.
    group_mode = Column(Boolean, default=False, nullable=False)

    created_at = Column(TIMESTAMP, server_default=func.now())
