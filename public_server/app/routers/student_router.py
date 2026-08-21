from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import PublicAuthActor, get_current_actor
from app.models.student_model import Student
from app.schemas.student_schema import StudentResponse

router = APIRouter(tags=["students"])


@router.get("/students/me", response_model=list[StudentResponse])
def get_my_students(
    db: Session = Depends(get_db),
    actor: PublicAuthActor = Depends(get_current_actor),
):
    if actor.role == "student" and actor.student is not None:
        students = [actor.student]
        parent = actor.student.parent
    else:
        # Only children still at the school. A pupil removed on the school
        # server arrives here as a deactivation rather than a delete, so
        # their history survives -- but leaving them in the parent's list
        # showed a child who has left as though they were still enrolled.
        students = db.query(Student).filter(
            Student.parent_id == actor.parent.id,
            Student.is_active == True,  # noqa: E712 -- SQLAlchemy column comparison
        ).order_by(Student.id.desc()).all()
        parent = actor.parent

    return [
        StudentResponse(
            id=student.id,
            class_id=student.local_class_id,
            parent_id=student.parent_id,
            class_name=student.class_name,
            parent_phone=parent.phone if parent else None,
            parent_name=parent.full_name if parent else None,
            first_name=student.first_name,
            last_name=student.last_name,
            photo=None,
            face_encoding=None,
            is_active=student.is_active,
        )
        for student in students
    ]
