from sqlalchemy import Column, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.database import Base


class Lesson(Base):
    """A recurring weekly timetable slot for a class: one subject, on one
    day of the week, starting at a fixed time and running `duration_minutes`
    (default 45) -- the unit the camera detection loop and absence marking
    use to know "what lesson is this class in right now."
    """

    __tablename__ = "lessons"

    id = Column(Integer, primary_key=True, index=True)

    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False, index=True)

    subject = Column(String, nullable=False)

    # Python's datetime.weekday(): Monday=0 .. Sunday=6.
    day_of_week = Column(Integer, nullable=False)

    start_time = Column(String, nullable=False)

    duration_minutes = Column(Integer, nullable=False, default=45)

    # Set when this row was generated from a camera position rather than
    # typed into the timetable.
    #
    # An academy keeps no lesson timetable -- its schedule is the camera's
    # list of groups. But the diary, the subject register and per-lesson
    # absence all read lessons, so a position writes matching lessons here
    # and every one of those keeps working with no special case. Deleting
    # the position deletes them again.
    position_id = Column(Integer, ForeignKey("camera_positions.id", ondelete="CASCADE"), nullable=True, index=True)

    teacher_id = Column(Integer, ForeignKey("teachers.id"), nullable=True)

    # Free text, same as `subject` -- no separate Room entity (see the
    # retired room_model.py/room_router.py, never wired into main.py).
    room = Column(String, nullable=True)

    school_class = relationship("Class")
    teacher = relationship("Teacher")

    @property
    def teacher_name(self) -> str | None:
        return self.teacher.full_name if self.teacher else None
