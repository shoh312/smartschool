from datetime import datetime, timedelta, timezone
from typing import Any, Literal, Optional

from pydantic import BaseModel, Field, field_validator, model_validator

# Tajikistan, UTC+5, no DST -- the same constant the journal router uses to
# decide what "today" means in a classroom.
SCHOOL_TZ = timezone(timedelta(hours=5))


def to_utc_naive(value: datetime | None) -> datetime | None:
    """Normalise an incoming deadline to naive UTC.

    Deadlines are compared against ``datetime.utcnow()`` on both servers, so
    they have to be *stored* in UTC. A phone sends either an offset-aware
    time or a bare local one; taking a bare "17:00" at face value would put
    the deadline five hours late in Dushanbe, quietly giving a class an
    extra evening on every control test.
    """
    if value is None:
        return None
    if value.tzinfo is None:
        # No offset: the teacher typed a wall-clock time, which is school time.
        value = value.replace(tzinfo=SCHOOL_TZ)
    return value.astimezone(timezone.utc).replace(tzinfo=None)

BlockType = Literal["page", "question"]
QuestionType = Literal["single", "truefalse", "fill", "match", "order"]
AssignmentMode = Literal["control", "practice"]


class MaterialBlockIn(BaseModel):
    block_type: BlockType
    body: str = ""
    question_type: Optional[QuestionType] = None
    options: Optional[Any] = None
    correct: Optional[Any] = None
    points: int = Field(default=1, ge=0, le=100)

    @model_validator(mode="after")
    def _check_shape(self):
        # A question with no `correct` can never be answered right, and the
        # pupil only finds out at the end -- reject it at authoring time
        # instead, while the teacher is still looking at it.
        if self.block_type == "question":
            if not self.question_type:
                raise ValueError("A question block needs a question_type")
            if not isinstance(self.correct, dict):
                raise ValueError("A question block needs a correct answer")
            if self.question_type in ("single", "match", "order") and not self.options:
                raise ValueError(f"{self.question_type} questions need options")
        return self


class MaterialBlockOut(MaterialBlockIn):
    id: int
    position: int

    class Config:
        from_attributes = True


class MaterialCreate(BaseModel):
    title: str = Field(min_length=1)
    description: Optional[str] = None
    # Optional: a teacher who has only one subject gets it filled in for them.
    subject: Optional[str] = None
    blocks: list[MaterialBlockIn] = []


class MaterialUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    # Replaces the whole run when present -- the editor always sends the
    # full ordered list, which keeps positions dense without a reorder API.
    blocks: Optional[list[MaterialBlockIn]] = None


class MaterialSummaryOut(BaseModel):
    """List row: everything the library screen shows, no block payload."""

    id: int
    title: str
    description: Optional[str] = None
    subject: str
    teacher_id: int
    teacher_name: Optional[str] = None
    question_count: int
    page_count: int
    max_score: int
    assigned_class_count: int
    updated_at: Optional[datetime] = None


class MaterialOut(MaterialSummaryOut):
    blocks: list[MaterialBlockOut] = []


class PasteImportRequest(BaseModel):
    text: str = Field(min_length=1)


class PasteImportResponse(BaseModel):
    blocks: list[MaterialBlockIn]


class AssignmentCreate(BaseModel):
    material_id: int
    class_ids: list[int] = Field(min_length=1)
    mode: AssignmentMode = "practice"
    due_at: Optional[datetime] = None
    max_attempts: Optional[int] = Field(default=None, ge=1, le=50)

    _normalise_due = field_validator("due_at")(lambda cls, v: to_utc_naive(v))


class AssignmentOut(BaseModel):
    id: int
    material_id: int
    material_title: str
    subject: str
    class_id: int
    class_name: Optional[str] = None
    teacher_id: int
    teacher_name: Optional[str] = None
    mode: AssignmentMode
    due_at: Optional[datetime] = None
    max_attempts: Optional[int] = None
    published_at: Optional[datetime] = None
    grades_transferred_at: Optional[datetime] = None
    question_count: int
    max_score: int
    student_count: int
    submitted_count: int
    # False until the deadline passes (or everyone has submitted) on a
    # control assignment -- see material_service.results_are_visible.
    results_visible: bool


class AssignmentResultRow(BaseModel):
    student_id: int
    student_name: str
    submitted_at: Optional[datetime] = None
    attempt_count: int = 0
    # All of these stay None until results_visible, so a locked assignment
    # can reuse the same response shape.
    score: Optional[int] = None
    max_score: Optional[int] = None
    percent: Optional[int] = None
    suggested_grade: Optional[int] = None
    transferred: bool = False


class AssignmentResultsOut(BaseModel):
    assignment: AssignmentOut
    results_visible: bool
    rows: list[AssignmentResultRow]


class GradeTransferItem(BaseModel):
    student_id: int
    value: int = Field(ge=1, le=10)


class GradeTransferRequest(BaseModel):
    items: list[GradeTransferItem] = Field(min_length=1)


class AiBlockOut(MaterialBlockIn):
    """A drafted block. Deliberately not MaterialBlockOut: nothing has been
    saved, so there is no id to report -- and inheriting MaterialBlockIn
    means the model's output is held to the same shape rules as anything a
    teacher types by hand before it is ever shown to them."""

    position: int = 0


class AiGenerateResponse(BaseModel):
    """A drafted material on its way to the teacher for review -- never
    straight into the library. `dropped_count` is how many blocks the model
    produced that couldn't be made answerable, so the app can say why there
    are eight questions when ten were asked for."""

    title: str = ""
    description: Optional[str] = None
    blocks: list[AiBlockOut] = []
    dropped_count: int = 0
