
from datetime import datetime

from fastapi import HTTPException
from sqlalchemy.orm import Session, selectinload

from app.models.class_model import Class
from app.models.material_model import (
    BLOCK_PAGE,
    BLOCK_QUESTION,
    MODE_CONTROL,
    Material,
    MaterialAssignment,
    MaterialAttempt,
    MaterialBlock,
)
from app.models.student import Student
from app.models.teacher_model import Teacher
from app.schemas.material_schema import (
    AssignmentOut,
    AssignmentResultRow,
    MaterialBlockIn,
    MaterialOut,
    MaterialSummaryOut,
)
from app.services.material_grading import suggest_grade
from app.services.teacher_service import teacher_can_grade_class


def get_owned_material(db: Session, material_id: int, teacher: Teacher) -> Material:
    material = get_readable_material(db, material_id, teacher.school_id)
    if material.teacher_id != teacher.id:
        raise HTTPException(
            status_code=403,
            detail="Only the teacher who wrote this material can change it",
        )
    return material


def get_readable_material(db: Session, material_id: int, school_id: int | None) -> Material:
    material = (
        db.query(Material)
        .options(selectinload(Material.blocks))
        .filter(Material.id == material_id)
        .first()
    )
    if not material or material.school_id != school_id:
        raise HTTPException(status_code=404, detail="Material not found")
    return material


def actor_school_id(actor) -> int | None:
    if actor.role == "director" and actor.director is not None:
        return actor.director.school_id
    if actor.role == "teacher" and actor.teacher is not None:
        return actor.teacher.school_id
    raise HTTPException(status_code=403, detail="Director or teacher access required")


def get_owned_assignment(db: Session, assignment_id: int, teacher: Teacher) -> MaterialAssignment:
    assignment = (
        db.query(MaterialAssignment)
        .filter(MaterialAssignment.id == assignment_id)
        .first()
    )
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")
    if assignment.teacher_id != teacher.id:
        raise HTTPException(
            status_code=403,
            detail="Only the teacher who set this assignment can manage it",
        )
    return assignment


def get_visible_assignment(db: Session, assignment_id: int, actor) -> MaterialAssignment:
    assignment = (
        db.query(MaterialAssignment)
        .filter(MaterialAssignment.id == assignment_id)
        .first()
    )
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")

    school_id = actor_school_id(actor)
    if assignment.material is None or assignment.material.school_id != school_id:
        raise HTTPException(status_code=404, detail="Assignment not found")

    if actor.role == "teacher" and assignment.teacher_id != actor.teacher.id:
        raise HTTPException(
            status_code=403,
            detail="Only the teacher who set this assignment can see its results",
        )
    return assignment


def require_teaches_class(
    db: Session, teacher: Teacher, class_id: int, subject: str | None = None
) -> Class:
    school_class = db.query(Class).filter(Class.id == class_id).first()
    if not school_class or school_class.school_id != teacher.school_id:
        raise HTTPException(status_code=404, detail="Class not found")

    if not teacher_can_grade_class(db, teacher.id, class_id, subject):
        raise HTTPException(
            status_code=403,
            detail="You are not assigned to teach that subject in that class",
        )
    return school_class


def replace_blocks(db: Session, material: Material, blocks: list[MaterialBlockIn]) -> None:
    for existing in list(material.blocks):
        db.delete(existing)
    db.flush()

    for position, block in enumerate(blocks):
        db.add(
            MaterialBlock(
                material_id=material.id,
                position=position,
                block_type=block.block_type,
                body=block.body or "",
                question_type=block.question_type,
                options=block.options,
                correct=block.correct,
                points=block.points,
            )
        )


def results_are_visible(
    assignment: MaterialAssignment,
    student_count: int,
    submitted_count: int,
    now: datetime | None = None,
) -> bool:
    if assignment.mode != MODE_CONTROL:
        return True
    if student_count and submitted_count >= student_count:
        return True
    if assignment.due_at is None:
        return False
    return (now or datetime.utcnow()) >= assignment.due_at


def _best_attempts(db: Session, assignment_id: int) -> dict[int, MaterialAttempt]:
    first: dict[int, MaterialAttempt] = {}
    attempts = (
        db.query(MaterialAttempt)
        .filter(
            MaterialAttempt.assignment_id == assignment_id,
            MaterialAttempt.submitted_at.isnot(None),
        )
        .order_by(MaterialAttempt.submitted_at.asc(), MaterialAttempt.id.asc())
        .all()
    )
    for attempt in attempts:
        first.setdefault(attempt.student_id, attempt)
    return first


def _attempt_counts(db: Session, assignment_id: int) -> dict[int, int]:
    counts: dict[int, int] = {}
    for attempt in (
        db.query(MaterialAttempt)
        .filter(MaterialAttempt.assignment_id == assignment_id)
        .all()
    ):
        counts[attempt.student_id] = counts.get(attempt.student_id, 0) + 1
    return counts


def assignment_out(db: Session, assignment: MaterialAssignment) -> AssignmentOut:
    material = assignment.material
    student_count = (
        db.query(Student).filter(Student.class_id == assignment.class_id).count()
    )
    submitted_count = len(_best_attempts(db, assignment.id))
    return AssignmentOut(
        id=assignment.id,
        material_id=material.id,
        material_title=material.title,
        subject=material.subject,
        class_id=assignment.class_id,
        class_name=assignment.school_class.name if assignment.school_class else None,
        teacher_id=assignment.teacher_id,
        teacher_name=assignment.teacher.full_name if assignment.teacher else None,
        mode=assignment.mode,
        due_at=assignment.due_at,
        max_attempts=assignment.max_attempts,
        published_at=assignment.published_at,
        grades_transferred_at=assignment.grades_transferred_at,
        question_count=material.question_count,
        max_score=material.max_score,
        student_count=student_count,
        submitted_count=submitted_count,
        results_visible=results_are_visible(assignment, student_count, submitted_count),
    )


def assignment_results(db: Session, assignment: MaterialAssignment) -> tuple[AssignmentOut, list[AssignmentResultRow]]:
    summary = assignment_out(db, assignment)
    students = (
        db.query(Student)
        .filter(Student.class_id == assignment.class_id)
        .order_by(Student.last_name, Student.first_name)
        .all()
    )
    best = _best_attempts(db, assignment.id)
    counts = _attempt_counts(db, assignment.id)

    rows: list[AssignmentResultRow] = []
    for student in students:
        attempt = best.get(student.id)
        row = AssignmentResultRow(
            student_id=student.id,
            student_name=f"{student.last_name} {student.first_name}".strip(),
            submitted_at=attempt.submitted_at if attempt else None,
            attempt_count=counts.get(student.id, 0),
            transferred=bool(attempt.transferred) if attempt else False,
        )
        if summary.results_visible and attempt is not None:
            percent = attempt.percent
            row.score = attempt.score
            row.max_score = attempt.max_score
            row.percent = percent
            row.suggested_grade = suggest_grade(percent)
        rows.append(row)
    return summary, rows


def material_summary_out(db: Session, material: Material) -> MaterialSummaryOut:
    assigned = (
        db.query(MaterialAssignment)
        .filter(MaterialAssignment.material_id == material.id)
        .count()
    )
    return MaterialSummaryOut(
        id=material.id,
        title=material.title,
        description=material.description,
        subject=material.subject,
        teacher_id=material.teacher_id,
        teacher_name=material.teacher_name,
        question_count=material.question_count,
        page_count=sum(1 for b in material.blocks if b.block_type == BLOCK_PAGE),
        max_score=material.max_score,
        assigned_class_count=assigned,
        updated_at=material.updated_at,
    )


def material_out(db: Session, material: Material) -> MaterialOut:
    summary = material_summary_out(db, material)
    return MaterialOut(
        **summary.model_dump(),
        blocks=[
            {
                "id": block.id,
                "position": block.position,
                "block_type": block.block_type,
                "body": block.body,
                "question_type": block.question_type,
                "options": block.options,
                "correct": block.correct,
                "points": block.points,
            }
            for block in sorted(material.blocks, key=lambda b: b.position)
        ],
    )


__all__ = [
    "BLOCK_PAGE",
    "BLOCK_QUESTION",
    "assignment_out",
    "assignment_results",
    "get_owned_assignment",
    "get_owned_material",
    "material_out",
    "material_summary_out",
    "replace_blocks",
    "require_teaches_class",
    "results_are_visible",
]
