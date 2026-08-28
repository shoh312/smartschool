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

    # Two switches the director owns, because both change what everyone
    # else in the school sees.
    #
    # Both carry a server_default as well as a Python one. `default=` is
    # applied by the ORM and is invisible to anything that writes SQL
    # directly -- and `ensure_default_school_and_backfill` does exactly that,
    # inserting the first school with a plain INSERT. On an existing database
    # the migration's own DEFAULT covered it; on a brand new one the table is
    # built by create_all instead, which emitted NOT NULL with no default at
    # all, and the very first startup died on its own seed row.
    #
    # A school that only wants attendance has no use for a live picture, and
    # a camera pointed at a classroom is not something to leave watchable by
    # default -- so it can be turned off for the whole school at once.
    live_video_enabled = Column(
        Boolean, default=True, server_default=text("true"), nullable=False
    )

    # Academies run several groups through one room in a day; ordinary
    # schools give each class its own room. With this off a camera belongs
    # to one class, as it always has; with it on the camera belongs to the
    # room and the timetable decides whose lesson is in front of it.
    group_mode = Column(
        Boolean, default=False, server_default=text("false"), nullable=False
    )

    created_at = Column(TIMESTAMP, server_default=func.now())
