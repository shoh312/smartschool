from sqlalchemy import Column, Date, ForeignKey, Integer, String, Text, TIMESTAMP
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.database import Base


class Grade(Base):

    __tablename__ = "grades"

    id = Column(Integer, primary_key=True, index=True)

    student_id = Column(Integer, ForeignKey("students.id"), nullable=False, index=True)

    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False, index=True)

    teacher_id = Column(Integer, ForeignKey("teachers.id"), nullable=False, index=True)

    subject = Column(String, nullable=False)

    quarter = Column(Integer, nullable=True)

    # The year the school year STARTS in (see academic_calendar.school_year_for_date)
    # -- disambiguates "quarter 1" across different years. Without it, once
    # a student has more than one year of grades, every quarter-scoped
    # average/ranking silently blends grades from every year they've
    # attended (same quarter number repeats every year).
    school_year = Column(Integer, nullable=True)

    value = Column(Integer, nullable=False)

    comment = Column(Text)

    grade_date = Column(Date, nullable=False, server_default=func.current_date())

    created_at = Column(TIMESTAMP, server_default=func.now())

    student = relationship("Student")
    school_class = relationship("Class")
    teacher = relationship("Teacher")

    @property
    def teacher_name(self) -> str | None:
        return self.teacher.full_name if self.teacher else None
