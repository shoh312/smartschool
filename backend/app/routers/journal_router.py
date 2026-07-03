from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import AuthActor, get_current_actor, get_current_teacher
from app.models.class_model import Class
from app.models.journal_model import Grade, Homework
from app.models.student import Student
from app.models.teacher_model import Teacher
from app.schemas.journal_schema import (
    GradeCreate,
    GradeResponse,
    HomeworkCreate,
    HomeworkResponse,
)
from app.services.teacher_service import teacher_can_grade_class

router = APIRouter(tags=["journal"])


def _require_student_in_class(db: Session, student_id: int, class_id: int) -> Student:
    student = db.query(Student).filter(
        Student.id == student_id,
        Student.class_id == class_id,
    ).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found in that class")
    return student


@router.post("/grades", response_model=GradeResponse)
def create_grade(
    payload: GradeCreate,
    db: Session = Depends(get_db),
    teacher: Teacher = Depends(get_current_teacher),
):
    if not teacher_can_grade_class(db, teacher.id, payload.class_id):
        raise HTTPException(status_code=403, detail="You are not assigned to this class")

    _require_student_in_class(db, payload.student_id, payload.class_id)

    grade = Grade(
        student_id=payload.student_id,
        class_id=payload.class_id,
        teacher_id=teacher.id,
        subject=payload.subject,
        value=payload.value,
        comment=payload.comment,
        grade_date=payload.grade_date or date.today(),
    )
    db.add(grade)
    db.commit()
    db.refresh(grade)
    return grade


@router.get("/grades", response_model=list[GradeResponse])
def list_grades(
    student_id: int | None = None,
    class_id: int | None = None,
    limit: int = 200,
    db: Session = Depends(get_db),
    actor: AuthActor = Depends(get_current_actor),
):
    query = db.query(Grade)

    if actor.role == "parent":
        if student_id is not None:
            student = db.query(Student).filter(Student.id == student_id).first()
            if not student or student.parent_id != actor.parent.id:
                raise HTTPException(status_code=403, detail="Not your student")
            query = query.filter(Grade.student_id == student_id)
        else:
            query = query.join(Student, Student.id == Grade.student_id).filter(
                Student.parent_id == actor.parent.id
            )
    elif actor.role == "teacher":
        query = query.filter(Grade.teacher_id == actor.teacher.id)
        if student_id is not None:
            query = query.filter(Grade.student_id == student_id)
        if class_id is not None:
            query = query.filter(Grade.class_id == class_id)
    else:  # director
        query = query.join(Student, Student.id == Grade.student_id).filter(
            Student.school_id == actor.director.school_id
        )
        if student_id is not None:
            query = query.filter(Grade.student_id == student_id)
        if class_id is not None:
            query = query.filter(Grade.class_id == class_id)

    return query.order_by(Grade.grade_date.desc(), Grade.id.desc()).limit(limit).all()


@router.post("/homework", response_model=HomeworkResponse)
def create_homework(
    payload: HomeworkCreate,
    db: Session = Depends(get_db),
    teacher: Teacher = Depends(get_current_teacher),
):
    if not teacher_can_grade_class(db, teacher.id, payload.class_id):
        raise HTTPException(status_code=403, detail="You are not assigned to this class")

    homework = Homework(
        class_id=payload.class_id,
        teacher_id=teacher.id,
        subject=payload.subject,
        description=payload.description,
        due_date=payload.due_date,
    )
    db.add(homework)
    db.commit()
    db.refresh(homework)
    return homework


@router.get("/homework", response_model=list[HomeworkResponse])
def list_homework(
    class_id: int | None = None,
    student_id: int | None = None,
    limit: int = 100,
    db: Session = Depends(get_db),
    actor: AuthActor = Depends(get_current_actor),
):
    query = db.query(Homework)

    if student_id is not None:
        student = db.query(Student).filter(Student.id == student_id).first()
        if not student:
            raise HTTPException(status_code=404, detail="Student not found")
        if actor.role == "parent" and student.parent_id != actor.parent.id:
            raise HTTPException(status_code=403, detail="Not your student")
        class_id = student.class_id

    if actor.role == "parent" and student_id is None:
        raise HTTPException(status_code=400, detail="student_id is required")
    if actor.role == "teacher":
        query = query.filter(Homework.teacher_id == actor.teacher.id)
    elif actor.role == "director" and class_id is None:
        school_class_ids = [
            row[0]
            for row in db.query(Class.id).filter(Class.school_id == actor.director.school_id).all()
        ]
        query = query.filter(Homework.class_id.in_(school_class_ids))

    if class_id is not None:
        query = query.filter(Homework.class_id == class_id)

    return query.order_by(Homework.due_date.desc().nullslast(), Homework.id.desc()).limit(limit).all()
