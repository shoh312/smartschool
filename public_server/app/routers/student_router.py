from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_parent
from app.models.parent_model import Parent
from app.models.student_model import Student
from app.schemas.student_schema import StudentResponse

router = APIRouter(tags=["students"])


@router.get("/students/me", response_model=list[StudentResponse])
def get_my_students(
    db: Session = Depends(get_db),
    parent: Parent = Depends(get_current_parent),
):
    students = db.query(Student).filter(Student.parent_id == parent.id).order_by(
        Student.id.desc()
    ).all()

    return [
        StudentResponse(
            id=student.id,
            class_id=student.local_class_id,
            parent_id=student.parent_id,
            class_name=student.class_name,
            parent_phone=parent.phone,
            parent_name=parent.full_name,
            first_name=student.first_name,
            last_name=student.last_name,
            photo=None,
            face_encoding=None,
            is_active=student.is_active,
        )
        for student in students
    ]
