from sqlalchemy import Column, ForeignKey, Integer, String, TIMESTAMP
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.database import Base


class CameraPosition(Base):
    """One slot of one camera's day: from when to when, and whose group is in
    front of it.

    A school gives each class its own room, so a camera belongs to a class
    and that is the end of it. An academy runs Python 4 through a room in the
    morning and Java 2 through the same room after lunch, with different
    pupils in each -- and a camera bound to one class can only ever recognise
    one of those groups.

    So in group mode the camera belongs to the *room* and this table says who
    is in it when. The detection loop asks "whose lesson is this, now" on
    every refresh and loads that group's faces; outside every slot it stays
    idle, the same way it does outside lesson hours today.

    `day_of_week` is Python's weekday() (Monday=0), or NULL for a slot that
    repeats every day -- which is how most academy timetables actually work.
    """

    __tablename__ = "camera_positions"

    id = Column(Integer, primary_key=True, index=True)

    camera_id = Column(Integer, ForeignKey("cameras.id", ondelete="CASCADE"), nullable=False, index=True)
    class_id = Column(Integer, ForeignKey("classes.id", ondelete="CASCADE"), nullable=False, index=True)

    # What is taught in this slot. Falls back to the group's own name,
    # which for an academy ("PYTHON 4") is usually the subject anyway.
    subject = Column(String, nullable=True)

    day_of_week = Column(Integer, nullable=True)

    # "HH:MM", validated at the API. Text rather than TIME for the same
    # reason lessons use text: it is what the form sends and what every
    # comparison in the detection loop already expects.
    start_time = Column(String, nullable=False)
    end_time = Column(String, nullable=False)

    created_at = Column(TIMESTAMP, server_default=func.now())

    camera = relationship("Camera")
    school_class = relationship("Class")
