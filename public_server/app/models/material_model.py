"""Mirror of the school server's learning materials, plus the one table
that originates *here*: pupils' attempts.

Everything else on this server is a read-only copy of local data. Attempts
are the exception -- a pupil sits at home with only this server reachable,
so their answers are written here first and pulled back to the school by the
local attempt worker (see the local `/sync/attempts` client). ``pulled_at``
is how this server remembers which rows have already made that trip.
"""

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    JSON,
    String,
    Text,
    TIMESTAMP,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.database import Base


class Material(Base):
    """Content, keyed by the school server's material id."""

    __tablename__ = "materials"
    __table_args__ = (
        UniqueConstraint("school_id", "local_material_id", name="uq_material_school_local"),
    )

    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("schools.id"), nullable=False, index=True)
    local_material_id = Column(Integer, nullable=False, index=True)

    subject = Column(String, nullable=False)
    title = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    teacher_name = Column(String, nullable=True)
    max_score = Column(Integer, nullable=False, default=0)

    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

    blocks = relationship(
        "MaterialBlock",
        back_populates="material",
        cascade="all, delete-orphan",
        order_by="MaterialBlock.position",
    )


class MaterialBlock(Base):
    """One screen of a material.

    ``correct`` is stored here so this server can mark the work itself; it
    is stripped from every pupil-facing response. Marking on the client
    would put the answer key in the app's network traffic, where a
    determined pupil would find it.
    """

    __tablename__ = "material_blocks"
    __table_args__ = (
        UniqueConstraint("material_id", "local_block_id", name="uq_block_material_local"),
    )

    id = Column(Integer, primary_key=True, index=True)
    material_id = Column(
        Integer, ForeignKey("materials.id", ondelete="CASCADE"), nullable=False, index=True
    )
    local_block_id = Column(Integer, nullable=False, index=True)

    position = Column(Integer, nullable=False)
    block_type = Column(String, nullable=False)
    body = Column(Text, nullable=False, default="")
    question_type = Column(String, nullable=True)
    options = Column(JSON, nullable=True)
    correct = Column(JSON, nullable=True)
    points = Column(Integer, nullable=False, default=1)

    material = relationship("Material", back_populates="blocks")


class MaterialAssignment(Base):
    """One material handed to one class, with its deadline and rules."""

    __tablename__ = "material_assignments"
    __table_args__ = (
        UniqueConstraint("school_id", "local_assignment_id", name="uq_assignment_school_local"),
    )

    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, ForeignKey("schools.id"), nullable=False, index=True)
    local_assignment_id = Column(Integer, nullable=False, index=True)

    local_material_id = Column(Integer, nullable=False, index=True)
    local_class_id = Column(Integer, nullable=False, index=True)
    class_name = Column(String, nullable=True)
    teacher_name = Column(String, nullable=True)

    mode = Column(String, nullable=False, default="practice")
    due_at = Column(DateTime, nullable=True)
    max_attempts = Column(Integer, nullable=True)
    published_at = Column(DateTime, nullable=True)

    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

    attempts = relationship(
        "MaterialAttempt",
        back_populates="assignment",
        cascade="all, delete-orphan",
    )


class MaterialAttempt(Base):
    """One pupil's run through one assignment -- written here, read there."""

    __tablename__ = "material_attempts"

    id = Column(Integer, primary_key=True, index=True)

    assignment_id = Column(
        Integer,
        ForeignKey("material_assignments.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    student_id = Column(Integer, ForeignKey("students.id"), nullable=False, index=True)

    attempt_no = Column(Integer, nullable=False, default=1)

    started_at = Column(DateTime, nullable=True)
    submitted_at = Column(DateTime, nullable=True, index=True)

    score = Column(Integer, nullable=True)
    max_score = Column(Integer, nullable=True)
    answers = Column(JSON, nullable=True)

    # Set once the school server has collected this attempt. Kept rather
    # than deleted so a pupil can still see their own past results.
    pulled_at = Column(DateTime, nullable=True, index=True)

    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

    assignment = relationship("MaterialAssignment", back_populates="attempts")
    student = relationship("Student")

    @property
    def percent(self) -> int | None:
        if self.score is None or not self.max_score:
            return None
        return round(self.score * 100 / self.max_score)
