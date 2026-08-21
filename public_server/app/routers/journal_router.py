from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import PublicAuthActor, get_current_actor, get_owned_student, student_ids_for_actor
from app.models.grade_model import Grade
from app.schemas.journal_schema import GradeResponse

router = APIRouter(tags=["journal"])


@router.get("/grades", response_model=list[GradeResponse])
def list_grades(
    student_id: int | None = None,
    limit: int = 200,
    db: Session = Depends(get_db),
    actor: PublicAuthActor = Depends(get_current_actor),
):
    query = db.query(Grade).filter(Grade.student_id.in_(student_ids_for_actor(db, actor)))
    if student_id is not None:
        get_owned_student(student_id, db, actor)
        query = query.filter(Grade.student_id == student_id)

    rows = query.order_by(Grade.grade_date.desc(), Grade.id.desc()).limit(limit).all()

    return [
        GradeResponse(
            id=grade.id,
            student_id=grade.student_id,
            class_id=grade.local_class_id,
            teacher_id=grade.local_teacher_id,
            teacher_name=grade.teacher_name,
            subject=grade.subject,
            value=grade.value,
            comment=grade.comment,
            grade_date=grade.grade_date,
            quarter=grade.quarter,
        )
        for grade in rows
    ]
