"""Pupil-facing learning materials, plus the parent's read-only view.

This is the only part of the feature a pupil at home can reach, so it is
also the only place the rules have to be *enforced* rather than merely
displayed:

* the answer key never leaves the server -- ``correct`` is stripped from
  every response and answers are marked here;
* a control test tells the pupil nothing about right/wrong, and hides even
  their own score, until the deadline has passed;
* attempt limits and deadlines are checked server-side, not trusted from
  the app.
"""

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, selectinload

from app.database import get_db
from app.deps import PublicAuthActor, get_current_actor, get_owned_student
from app.models.material_model import (
    Material,
    MaterialAssignment,
    MaterialAttempt,
    MaterialBlock,
)
from app.models.student_model import Student
from app.schemas.material_schema import (
    AnswerIn,
    AnswerOut,
    AttemptResultOut,
    StudentAssignmentDetailOut,
    StudentAssignmentOut,
    StudentBlockOut,
)
from app.services.material_grading import is_answer_correct, score_attempt

router = APIRouter(prefix="/materials", tags=["materials"])

MODE_CONTROL = "control"


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

def _require_self(actor: PublicAuthActor, student: Student) -> None:
    """Only the pupil themself may answer. A parent can watch, but must not
    be able to sit the test for their child."""
    if actor.role != "student" or actor.student is None or actor.student.id != student.id:
        raise HTTPException(status_code=403, detail="Only the student can do this work")


def _material_for(db: Session, assignment: MaterialAssignment) -> Material | None:
    return (
        db.query(Material)
        .options(selectinload(Material.blocks))
        .filter(
            Material.school_id == assignment.school_id,
            Material.local_material_id == assignment.local_material_id,
        )
        .first()
    )


def _is_overdue(assignment: MaterialAssignment, now: datetime | None = None) -> bool:
    if assignment.due_at is None:
        return False
    return (now or datetime.utcnow()) > assignment.due_at


def _class_all_submitted(db: Session, assignment: MaterialAssignment) -> bool:
    student_count = (
        db.query(Student)
        .filter(
            Student.school_id == assignment.school_id,
            Student.local_class_id == assignment.local_class_id,
            Student.is_active == True,  # noqa: E712 -- SQLAlchemy column comparison
        )
        .count()
    )
    if not student_count:
        return False
    submitted = (
        db.query(MaterialAttempt.student_id)
        .filter(
            MaterialAttempt.assignment_id == assignment.id,
            MaterialAttempt.submitted_at.isnot(None),
        )
        .distinct()
        .count()
    )
    return submitted >= student_count


def _score_visible(db: Session, assignment: MaterialAssignment) -> bool:
    """Mirrors the school server's rule, for the same reason: the first
    pupil to finish a control test must not learn their mark (and by
    extension how they did on each question) while the rest are still
    working.
    """
    if assignment.mode != MODE_CONTROL:
        return True
    if _is_overdue(assignment):
        return True
    return _class_all_submitted(db, assignment)


def _attempts_of(db: Session, assignment_id: int, student_id: int) -> list[MaterialAttempt]:
    return (
        db.query(MaterialAttempt)
        .filter(
            MaterialAttempt.assignment_id == assignment_id,
            MaterialAttempt.student_id == student_id,
        )
        .order_by(MaterialAttempt.attempt_no.asc())
        .all()
    )


def _best_submitted(attempts: list[MaterialAttempt]) -> MaterialAttempt | None:
    submitted = [a for a in attempts if a.submitted_at is not None]
    if not submitted:
        return None
    return max(submitted, key=lambda a: (a.score or 0, a.submitted_at))


def _summarise(
    db: Session,
    assignment: MaterialAssignment,
    material: Material,
    student: Student,
) -> StudentAssignmentOut:
    attempts = _attempts_of(db, assignment.id, student.id)
    best = _best_submitted(attempts)
    used = len(attempts)
    left = None if assignment.max_attempts is None else max(assignment.max_attempts - used, 0)
    overdue = _is_overdue(assignment)
    visible = _score_visible(db, assignment)

    questions = [b for b in material.blocks if b.block_type == "question"]

    return StudentAssignmentOut(
        id=assignment.id,
        material_id=material.id,
        title=material.title,
        description=material.description,
        subject=material.subject,
        teacher_name=assignment.teacher_name or material.teacher_name,
        class_name=assignment.class_name,
        mode=assignment.mode,
        due_at=assignment.due_at,
        max_attempts=assignment.max_attempts,
        question_count=len(questions),
        max_score=sum(b.points or 0 for b in questions),
        attempts_used=used,
        attempts_left=left,
        submitted_at=best.submitted_at if best else None,
        is_overdue=overdue,
        can_start=not overdue and (left is None or left > 0),
        score=best.score if (best and visible) else None,
        percent=best.percent if (best and visible) else None,
        score_visible=visible,
    )


# --------------------------------------------------------------------------
# Reading
# --------------------------------------------------------------------------

@router.get("/assignments", response_model=list[StudentAssignmentOut])
def list_assignments(
    student_id: int,
    db: Session = Depends(get_db),
    actor: PublicAuthActor = Depends(get_current_actor),
):
    """Everything handed to this pupil's class. Serves the pupil and, with
    the same payload, their parent -- a parent sees status and (once
    revealed) the score, but has no way to start or answer anything."""
    student = get_owned_student(student_id, db, actor)
    if student.local_class_id is None:
        return []

    assignments = (
        db.query(MaterialAssignment)
        .filter(
            MaterialAssignment.school_id == student.school_id,
            MaterialAssignment.local_class_id == student.local_class_id,
            MaterialAssignment.published_at.isnot(None),
        )
        .order_by(MaterialAssignment.due_at.asc().nullslast(), MaterialAssignment.id.desc())
        .all()
    )

    out: list[StudentAssignmentOut] = []
    for assignment in assignments:
        material = _material_for(db, assignment)
        # A published assignment whose material hasn't landed yet (outbox
        # ordering) is skipped rather than shown as an empty broken card.
        if material is None:
            continue
        out.append(_summarise(db, assignment, material, student))
    return out


@router.get("/assignments/{assignment_id}", response_model=StudentAssignmentDetailOut)
def get_assignment(
    assignment_id: int,
    student_id: int,
    db: Session = Depends(get_db),
    actor: PublicAuthActor = Depends(get_current_actor),
):
    student = get_owned_student(student_id, db, actor)
    assignment = _require_assignment(db, assignment_id, student)
    material = _material_for(db, assignment)
    if material is None:
        raise HTTPException(status_code=404, detail="Material not available yet")

    summary = _summarise(db, assignment, material, student)

    attempts = _attempts_of(db, assignment.id, student.id)
    open_attempt = next((a for a in attempts if a.submitted_at is None), None)

    return StudentAssignmentDetailOut(
        **summary.model_dump(),
        attempt_id=open_attempt.id if open_attempt else None,
        saved_answers=(open_attempt.answers or {}) if open_attempt else {},
        blocks=[
            StudentBlockOut(
                id=block.id,
                position=block.position,
                block_type=block.block_type,
                body=block.body,
                question_type=block.question_type,
                options=block.options,
                points=block.points,
            )
            for block in sorted(material.blocks, key=lambda b: b.position)
        ],
    )


def _require_assignment(db: Session, assignment_id: int, student: Student) -> MaterialAssignment:
    assignment = (
        db.query(MaterialAssignment)
        .filter(MaterialAssignment.id == assignment_id)
        .first()
    )
    if (
        not assignment
        or assignment.published_at is None
        or assignment.school_id != student.school_id
        or assignment.local_class_id != student.local_class_id
    ):
        raise HTTPException(status_code=404, detail="Assignment not found")
    return assignment


# --------------------------------------------------------------------------
# Doing the work
# --------------------------------------------------------------------------

@router.post("/assignments/{assignment_id}/start", response_model=StudentAssignmentDetailOut)
def start_attempt(
    assignment_id: int,
    student_id: int,
    db: Session = Depends(get_db),
    actor: PublicAuthActor = Depends(get_current_actor),
):
    student = get_owned_student(student_id, db, actor)
    _require_self(actor, student)
    assignment = _require_assignment(db, assignment_id, student)
    material = _material_for(db, assignment)
    if material is None:
        raise HTTPException(status_code=404, detail="Material not available yet")

    if _is_overdue(assignment):
        raise HTTPException(status_code=409, detail="The deadline for this work has passed")

    attempts = _attempts_of(db, assignment.id, student.id)
    open_attempt = next((a for a in attempts if a.submitted_at is None), None)
    if open_attempt is None:
        # Only finished runs count against the limit -- an unfinished one is
        # resumed above, so closing the app can't burn an attempt.
        if assignment.max_attempts is not None and len(attempts) >= assignment.max_attempts:
            raise HTTPException(status_code=409, detail="No attempts left")
        open_attempt = MaterialAttempt(
            assignment_id=assignment.id,
            student_id=student.id,
            attempt_no=len(attempts) + 1,
            started_at=datetime.utcnow(),
            answers={},
        )
        db.add(open_attempt)
        db.commit()
        db.refresh(open_attempt)

    return get_assignment(assignment_id, student_id, db, actor)


@router.post("/attempts/{attempt_id}/answer", response_model=AnswerOut)
def record_answer(
    attempt_id: int,
    payload: AnswerIn,
    db: Session = Depends(get_db),
    actor: PublicAuthActor = Depends(get_current_actor),
):
    """Save one answer, and in practice mode say whether it was right.

    Saving as the pupil goes (rather than posting everything at the end)
    means a dropped connection or a closed app costs them nothing.
    """
    attempt = _require_open_attempt(db, attempt_id, actor)
    assignment = attempt.assignment

    block = (
        db.query(MaterialBlock)
        .filter(MaterialBlock.id == payload.block_id)
        .first()
    )
    material = _material_for(db, assignment)
    if block is None or material is None or block.material_id != material.id:
        raise HTTPException(status_code=404, detail="Question not found in this material")
    if block.block_type != "question":
        raise HTTPException(status_code=400, detail="That block is not a question")

    # JSON object keys are strings once this has been through Postgres, so
    # store them as strings from the start -- otherwise a resumed attempt
    # looks up "12" and misses the int key 12 it saved earlier.
    answers = dict(attempt.answers or {})
    answers[str(payload.block_id)] = payload.answer
    attempt.answers = answers
    db.commit()

    if assignment.mode == MODE_CONTROL:
        return AnswerOut(saved=True, correct=None)
    return AnswerOut(
        saved=True,
        correct=is_answer_correct(block.question_type, block.correct, payload.answer),
    )


@router.post("/attempts/{attempt_id}/submit", response_model=AttemptResultOut)
def submit_attempt(
    attempt_id: int,
    db: Session = Depends(get_db),
    actor: PublicAuthActor = Depends(get_current_actor),
):
    attempt = _require_open_attempt(db, attempt_id, actor)
    assignment = attempt.assignment
    material = _material_for(db, assignment)
    if material is None:
        raise HTTPException(status_code=404, detail="Material not available yet")

    # A late submit is still accepted and marked: the pupil answered inside
    # the window and only pressed the button after it closed (or their
    # connection stalled). Refusing here would throw the work away. What the
    # deadline does stop is *starting* a new attempt.
    questions = [b for b in material.blocks if b.block_type == "question"]
    score, max_score = score_attempt(questions, attempt.answers or {})

    attempt.score = score
    attempt.max_score = max_score
    attempt.submitted_at = datetime.utcnow()
    db.commit()
    db.refresh(attempt)

    visible = _score_visible(db, assignment)
    per_question = None
    if visible and assignment.mode != MODE_CONTROL:
        answers = {str(k): v for k, v in (attempt.answers or {}).items()}
        per_question = {
            str(block.id): is_answer_correct(
                block.question_type, block.correct, answers.get(str(block.id))
            )
            for block in questions
        }

    return AttemptResultOut(
        attempt_id=attempt.id,
        submitted_at=attempt.submitted_at,
        score_visible=visible,
        score=score if visible else None,
        max_score=max_score if visible else None,
        percent=attempt.percent if visible else None,
        per_question=per_question,
    )


def _require_open_attempt(
    db: Session, attempt_id: int, actor: PublicAuthActor
) -> MaterialAttempt:
    attempt = db.query(MaterialAttempt).filter(MaterialAttempt.id == attempt_id).first()
    if not attempt:
        raise HTTPException(status_code=404, detail="Attempt not found")
    if actor.role != "student" or actor.student is None or attempt.student_id != actor.student.id:
        raise HTTPException(status_code=403, detail="Not your attempt")
    if attempt.submitted_at is not None:
        raise HTTPException(status_code=409, detail="This attempt has already been submitted")
    return attempt
