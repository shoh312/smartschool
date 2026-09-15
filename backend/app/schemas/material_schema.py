from datetime import datetime, timedelta, timezone
from typing import Any, Literal, Optional

from pydantic import BaseModel, Field, field_validator, model_validator

SCHOOL_TZ = timezone(timedelta(hours=5))


def to_utc_naive(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is None:
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
    subject: Optional[str] = None
    blocks: list[MaterialBlockIn] = []


class MaterialUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    blocks: Optional[list[MaterialBlockIn]] = None


class MaterialSummaryOut(BaseModel):

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
    results_visible: bool


class AssignmentResultRow(BaseModel):
    student_id: int
    student_name: str
    submitted_at: Optional[datetime] = None
    attempt_count: int = 0
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

    position: int = 0


class AiGenerateResponse(BaseModel):

    title: str = ""
    description: Optional[str] = None
    blocks: list[AiBlockOut] = []
    dropped_count: int = 0
