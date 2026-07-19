from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_parent
from app.models.grade_model import Grade
from app.models.parent_model import Parent
from app.models.student_model import Student
from app.schemas.journal_schema import GradeResponse

router = APIRouter(tags=["journal"])


@router.get("/grades", response_model=list[GradeResponse])
def list_grades(
    student_id: int | None = None,
    limit: int = 200,
    db: Session = Depends(get_db),
    parent: Parent = Depends(get_current_parent),
):
    query = db.query(Grade).join(Student, Student.id == Grade.student_id).filter(
        Student.parent_id == parent.id
    )
    if student_id is not None:
        student = db.query(Student).filter(Student.id == student_id).first()
        if not student or student.parent_id != parent.id:
            raise HTTPException(status_code=403, detail="Not your student")
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
        )
        for grade in rows
    ]
