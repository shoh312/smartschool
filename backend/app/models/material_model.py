
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

BLOCK_PAGE = "page"
BLOCK_QUESTION = "question"

Q_SINGLE = "single"
Q_TRUEFALSE = "truefalse"
Q_FILL = "fill"
Q_MATCH = "match"
Q_ORDER = "order"

QUESTION_TYPES = {Q_SINGLE, Q_TRUEFALSE, Q_FILL, Q_MATCH, Q_ORDER}

MODE_CONTROL = "control"
MODE_PRACTICE = "practice"

ASSIGNMENT_MODES = {MODE_CONTROL, MODE_PRACTICE}


class Material(Base):

    __tablename__ = "materials"

    id = Column(Integer, primary_key=True, index=True)

    school_id = Column(Integer, ForeignKey("schools.id"), nullable=False, index=True)

    teacher_id = Column(Integer, ForeignKey("teachers.id"), nullable=False, index=True)

    subject = Column(String, nullable=False, index=True)

    title = Column(String, nullable=False)

    description = Column(Text, nullable=True)

    created_at = Column(TIMESTAMP, server_default=func.now())
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

    teacher = relationship("Teacher")
    blocks = relationship(
        "MaterialBlock",
        back_populates="material",
        cascade="all, delete-orphan",
        order_by="MaterialBlock.position",
    )
    assignments = relationship(
        "MaterialAssignment",
        back_populates="material",
        cascade="all, delete-orphan",
    )

    @property
    def teacher_name(self) -> str | None:
        return self.teacher.full_name if self.teacher else None

    @property
    def question_count(self) -> int:
        return sum(1 for block in self.blocks if block.block_type == BLOCK_QUESTION)

    @property
    def max_score(self) -> int:
        return sum(
            block.points or 0
            for block in self.blocks
            if block.block_type == BLOCK_QUESTION
        )


class MaterialBlock(Base):

    __tablename__ = "material_blocks"

    id = Column(Integer, primary_key=True, index=True)

    material_id = Column(
        Integer, ForeignKey("materials.id", ondelete="CASCADE"), nullable=False, index=True
    )

    position = Column(Integer, nullable=False)

    block_type = Column(String, nullable=False)

    body = Column(Text, nullable=False, default="")

    question_type = Column(String, nullable=True)

    options = Column(JSON, nullable=True)

    correct = Column(JSON, nullable=True)

    points = Column(Integer, nullable=False, default=1)

    material = relationship("Material", back_populates="blocks")


class MaterialAssignment(Base):

    __tablename__ = "material_assignments"

    id = Column(Integer, primary_key=True, index=True)

    material_id = Column(
        Integer, ForeignKey("materials.id", ondelete="CASCADE"), nullable=False, index=True
    )

    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False, index=True)

    teacher_id = Column(Integer, ForeignKey("teachers.id"), nullable=False, index=True)

    mode = Column(String, nullable=False, default=MODE_PRACTICE)

    due_at = Column(DateTime, nullable=True)

    max_attempts = Column(Integer, nullable=True)

    published_at = Column(DateTime, nullable=True)

    grades_transferred_at = Column(DateTime, nullable=True)

    created_at = Column(TIMESTAMP, server_default=func.now())
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

    material = relationship("Material", back_populates="assignments")
    school_class = relationship("Class")
    teacher = relationship("Teacher")
    attempts = relationship(
        "MaterialAttempt",
        back_populates="assignment",
        cascade="all, delete-orphan",
    )

    __table_args__ = (
        UniqueConstraint("material_id", "class_id", name="uq_assignment_material_class"),
    )


class MaterialAttempt(Base):

    __tablename__ = "material_attempts"

    id = Column(Integer, primary_key=True, index=True)

    public_id = Column(Integer, nullable=True, unique=True, index=True)

    assignment_id = Column(
        Integer,
        ForeignKey("material_assignments.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    student_id = Column(Integer, ForeignKey("students.id"), nullable=False, index=True)

    attempt_no = Column(Integer, nullable=False, default=1)

    started_at = Column(DateTime, nullable=True)

    submitted_at = Column(DateTime, nullable=True)

    score = Column(Integer, nullable=True)
    max_score = Column(Integer, nullable=True)

    answers = Column(JSON, nullable=True)

    transferred = Column(Boolean, nullable=False, default=False)

    assignment = relationship("MaterialAssignment", back_populates="attempts")
    student = relationship("Student")

    @property
    def percent(self) -> int | None:
        if self.score is None or not self.max_score:
            return None
        return round(self.score * 100 / self.max_score)
