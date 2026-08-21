"""Teacher-authored learning material: a lesson a pupil walks through on
their phone, one screen at a time, with questions mixed in between the
explanation pages (the "Duolingo" shape the school asked for).

Four tables, deliberately split:

* ``Material``            -- the content itself, and nothing about *when* or
                             *to whom* it was given. This is what makes a
                             teacher's library work: write it once, hand it to
                             10A today and 10B tomorrow, and again next year.
* ``MaterialBlock``       -- one screen of that content, ordered. Either an
                             explanation page or a question.
* ``MaterialAssignment``  -- one handing-out: material + class + deadline +
                             whether it counts as a control test or practice.
* ``MaterialAttempt``     -- one pupil's run through one assignment.

Attempts are the odd one out: pupils work from home, so they are *created on
the Public Server* and pulled back here afterwards (see the attempt pull
worker). Everything else flows the usual way, local -> public.
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

# Block kinds
BLOCK_PAGE = "page"
BLOCK_QUESTION = "question"

# Question kinds. Kept as plain strings rather than a DB enum so adding a
# type later is a code change, not a migration.
Q_SINGLE = "single"        # one correct option out of several
Q_TRUEFALSE = "truefalse"  # to'g'ri / noto'g'ri
Q_FILL = "fill"            # pupil types the answer
Q_MATCH = "match"          # pair left items with right items
Q_ORDER = "order"          # put the items in the right order

QUESTION_TYPES = {Q_SINGLE, Q_TRUEFALSE, Q_FILL, Q_MATCH, Q_ORDER}

# Assignment modes
MODE_CONTROL = "control"    # counts: score hidden until the deadline passes
MODE_PRACTICE = "practice"  # no grade: pupil is told right/wrong immediately

ASSIGNMENT_MODES = {MODE_CONTROL, MODE_PRACTICE}


class Material(Base):
    """A reusable piece of content owned by one teacher."""

    __tablename__ = "materials"

    id = Column(Integer, primary_key=True, index=True)

    school_id = Column(Integer, ForeignKey("schools.id"), nullable=False, index=True)

    teacher_id = Column(Integer, ForeignKey("teachers.id"), nullable=False, index=True)

    # Matches Lesson.subject / Grade.subject -- free text, Cyrillic in this
    # school ("Математика"). A teacher may only author for their own subject.
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
    """One screen: either an explanation page or a question.

    ``options`` and ``correct`` are JSON because their shape depends on
    ``question_type``:

    * single    options ``["Dushanbe", "Xujand"]``      correct ``{"index": 0}``
    * truefalse options ``null``                        correct ``{"value": true}``
    * fill      options ``null``                        correct ``{"answers": ["Dushanbe", "Душанбе"]}``
    * match     options ``{"left": [...], "right": [...]}``  correct ``{"pairs": [[0, 1], [1, 0]]}``
    * order     options ``["Yer", "Quyosh", "atrofida"]``    correct ``{"order": [1, 2, 0]}``

    ``correct`` is never sent to a pupil's device -- grading happens on the
    server so the answers can't be read out of the app's network traffic.
    """

    __tablename__ = "material_blocks"

    id = Column(Integer, primary_key=True, index=True)

    material_id = Column(
        Integer, ForeignKey("materials.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # 0-based, dense. Reordering rewrites the whole run rather than trying to
    # be clever with gaps -- a material is a few dozen blocks at most.
    position = Column(Integer, nullable=False)

    block_type = Column(String, nullable=False)

    # Page text, or the question itself.
    body = Column(Text, nullable=False, default="")

    question_type = Column(String, nullable=True)

    options = Column(JSON, nullable=True)

    correct = Column(JSON, nullable=True)

    points = Column(Integer, nullable=False, default=1)

    material = relationship("Material", back_populates="blocks")


class MaterialAssignment(Base):
    """One material handed to one class, with its own deadline and rules.

    Deadline and attempt limit live here, not on the material: the same test
    can be a timed control in 10A and open-ended practice in 10B.
    """

    __tablename__ = "material_assignments"

    id = Column(Integer, primary_key=True, index=True)

    material_id = Column(
        Integer, ForeignKey("materials.id", ondelete="CASCADE"), nullable=False, index=True
    )

    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False, index=True)

    # Denormalised from the material so results and permission checks don't
    # need a join, and so an assignment keeps working if the teacher later
    # edits the material's subject.
    teacher_id = Column(Integer, ForeignKey("teachers.id"), nullable=False, index=True)

    mode = Column(String, nullable=False, default=MODE_PRACTICE)

    due_at = Column(DateTime, nullable=True)

    # NULL means unlimited -- what a teacher wants for practice.
    max_attempts = Column(Integer, nullable=True)

    # Set when the teacher hands it out. A row with no published_at is not
    # visible to pupils yet.
    published_at = Column(DateTime, nullable=True)

    # Flipped once the teacher has pushed the scores into the journal, so the
    # UI can stop offering to do it twice.
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
    """One pupil's run through one assignment.

    Written by the Public Server (that's where the pupil is) and copied here
    by the pull worker, so ``public_id`` is the identity that survives the
    trip -- the local autoincrement id means nothing to the other side.
    """

    __tablename__ = "material_attempts"

    id = Column(Integer, primary_key=True, index=True)

    # The Public Server's row id. Unique so re-pulling the same attempt
    # updates it in place instead of duplicating it.
    public_id = Column(Integer, nullable=True, unique=True, index=True)

    assignment_id = Column(
        Integer,
        ForeignKey("material_assignments.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    student_id = Column(Integer, ForeignKey("students.id"), nullable=False, index=True)

    # 1-based; compared against MaterialAssignment.max_attempts.
    attempt_no = Column(Integer, nullable=False, default=1)

    started_at = Column(DateTime, nullable=True)

    # NULL while still in progress. "Who has finished" is exactly this being
    # non-NULL -- the one thing a teacher may see before the deadline.
    submitted_at = Column(DateTime, nullable=True)

    score = Column(Integer, nullable=True)
    max_score = Column(Integer, nullable=True)

    # block_id -> whatever the pupil chose/typed, in the same shape as the
    # block's `correct`. Kept so a teacher can review an individual answer.
    answers = Column(JSON, nullable=True)

    # Set when this attempt's score has been turned into a journal grade, so
    # a second transfer doesn't double-grade the pupil.
    transferred = Column(Boolean, nullable=False, default=False)

    assignment = relationship("MaterialAssignment", back_populates="attempts")
    student = relationship("Student")

    @property
    def percent(self) -> int | None:
        if self.score is None or not self.max_score:
            return None
        return round(self.score * 100 / self.max_score)
