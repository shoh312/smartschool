from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


class StudentBlockOut(BaseModel):
    """A block as the pupil's device sees it.

    Note what is missing: ``correct``. The answer key never leaves this
    server -- marking happens here, so it cannot be read out of the app's
    network traffic.
    """

    id: int
    position: int
    block_type: str
    body: str
    question_type: Optional[str] = None
    options: Optional[Any] = None
    points: int = 1


class StudentAssignmentOut(BaseModel):
    id: int
    material_id: int
    title: str
    description: Optional[str] = None
    subject: str
    teacher_name: Optional[str] = None
    class_name: Optional[str] = None
    mode: str
    due_at: Optional[datetime] = None
    max_attempts: Optional[int] = None
    question_count: int
    max_score: int

    # This pupil's own state
    attempts_used: int = 0
    attempts_left: Optional[int] = None   # None = unlimited
    submitted_at: Optional[datetime] = None
    is_overdue: bool = False
    can_start: bool = False
    # Filled only once the pupil is allowed to know: practice work reveals
    # it straight away, control work not until the deadline has passed.
    score: Optional[int] = None
    percent: Optional[int] = None
    score_visible: bool = False


class StudentAssignmentDetailOut(StudentAssignmentOut):
    blocks: list[StudentBlockOut] = []
    attempt_id: Optional[int] = None
    # block_id -> the answer already recorded in this attempt, so a pupil who
    # closes the app mid-test picks up where they left off.
    saved_answers: dict[str, Any] = {}


class AnswerIn(BaseModel):
    block_id: int
    answer: Any


class AnswerOut(BaseModel):
    saved: bool = True
    # None in control mode -- the pupil is told nothing until the deadline.
    correct: Optional[bool] = None


class AttemptResultOut(BaseModel):
    attempt_id: int
    submitted_at: datetime
    score_visible: bool
    score: Optional[int] = None
    max_score: Optional[int] = None
    percent: Optional[int] = None
    # block_id -> whether it was right. Practice mode only.
    per_question: Optional[dict[str, bool]] = None


# --------------------------------------------------------------------------
# Sync (school server pulling attempts back)
# --------------------------------------------------------------------------

class AttemptSyncRow(BaseModel):
    public_id: int
    local_assignment_id: int
    local_student_id: int
    attempt_no: int
    started_at: Optional[datetime] = None
    submitted_at: Optional[datetime] = None
    score: Optional[int] = None
    max_score: Optional[int] = None
    answers: Optional[Any] = None


class AttemptAckRequest(BaseModel):
    public_ids: list[int] = Field(min_length=1)
