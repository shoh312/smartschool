from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_director, get_current_teacher
from app.models.class_model import Class
from app.models.director_model import Director
from app.models.journal_model import Grade
from app.models.parent_model import Parent
from app.models.student import Student
from app.models.teacher_model import Teacher, TeacherClass
from app.schemas.student_schema import StudentResponse
from app.schemas.teacher_schema import (
    ClassAssignmentCreate,
    ClassAssignmentResponse,
    ClassSubjectResponse,
    TeacherCreate,
    TeacherLogin,
    TeacherResponse,
    TeacherTokenResponse,
)
from app.services.teacher_service import (
    assign_class,
    authenticate_teacher,
    create_teacher,
    create_teacher_token,
    remove_class_assignment,
    teacher_can_grade_class,
)

router = APIRouter(tags=["teachers"])


def _require_teacher(db: Session, teacher_id: int, director: Director) -> Teacher:
    teacher = db.query(Teacher).filter(
        Teacher.id == teacher_id,
        Teacher.school_id == director.school_id,
    ).first()
    if not teacher:
        raise HTTPException(status_code=404, detail="Teacher not found")
    return teacher


@router.post("/auth/teacher/login", response_model=TeacherTokenResponse)
def login_teacher(payload: TeacherLogin, db: Session = Depends(get_db)):
    teacher = authenticate_teacher(db, email=str(payload.email), password=payload.password)
    return TeacherTokenResponse(
        access_token=create_teacher_token(teacher),
        teacher=teacher,
    )


@router.get("/auth/teacher/me", response_model=TeacherResponse)
def teacher_me(current_teacher: Teacher = Depends(get_current_teacher)):
    return current_teacher


@router.post(
    "/teachers",
    response_model=TeacherResponse,
    dependencies=[Depends(get_current_director)],
)
def director_create_teacher(
    payload: TeacherCreate,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    return create_teacher(
        db,
        school_id=director.school_id,
        full_name=payload.full_name,
        email=str(payload.email),
        password=payload.password,
        subject=payload.subject,
    )


@router.get(
    "/teachers",
    response_model=list[TeacherResponse],
    dependencies=[Depends(get_current_director)],
)
def list_teachers(
    subject: str | None = None,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    query = db.query(Teacher).filter(Teacher.school_id == director.school_id)
    if subject is not None:
        query = query.filter(Teacher.subject == subject)
    return query.order_by(Teacher.full_name.asc()).all()


@router.post(
    "/teachers/{teacher_id}/classes",
    response_model=ClassAssignmentResponse,
    dependencies=[Depends(get_current_director)],
)
def director_assign_class(
    teacher_id: int,
    payload: ClassAssignmentCreate,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    teacher = db.query(Teacher).filter(
        Teacher.id == teacher_id,
        Teacher.school_id == director.school_id,
    ).first()
    if not teacher:
        raise HTTPException(status_code=404, detail="Teacher not found")

    assignment = assign_class(
        db,
        teacher=teacher,
        class_id=payload.class_id,
        subject=payload.subject,
        school_id=director.school_id,
    )
    school_class = db.query(Class).filter(Class.id == assignment.class_id).first()
    return ClassAssignmentResponse(
        id=assignment.id,
        class_id=assignment.class_id,
        subject=assignment.subject,
        class_name=school_class.name if school_class else None,
    )


@router.get(
    "/teachers/me/classes",
    response_model=list[ClassAssignmentResponse],
    dependencies=[Depends(get_current_teacher)],
)
def teacher_my_classes(
    db: Session = Depends(get_db),
    teacher: Teacher = Depends(get_current_teacher),
):
    rows = db.query(TeacherClass, Class).join(
        Class, Class.id == TeacherClass.class_id
    ).filter(TeacherClass.teacher_id == teacher.id).all()

    return [
        ClassAssignmentResponse(
            id=assignment.id,
            class_id=assignment.class_id,
            subject=assignment.subject,
            class_name=school_class.name,
        )
        for assignment, school_class in rows
    ]


@router.get(
    "/teachers/me/classes/{class_id}/students",
    response_model=list[StudentResponse],
    dependencies=[Depends(get_current_teacher)],
)
def teacher_class_roster(
    class_id: int,
    db: Session = Depends(get_db),
    teacher: Teacher = Depends(get_current_teacher),
):
    if not teacher_can_grade_class(db, teacher.id, class_id):
        raise HTTPException(status_code=403, detail="You are not assigned to this class")

    rows = db.query(Student, Class, Parent).filter(
        Student.class_id == class_id
    ).outerjoin(
        Class, Student.class_id == Class.id
    ).outerjoin(
        Parent, Student.parent_id == Parent.id
    ).order_by(Student.first_name.asc()).all()

    return [
        StudentResponse(
            id=student.id,
            class_id=student.class_id,
            parent_id=student.parent_id,
            class_name=school_class.name if school_class else None,
            parent_phone=parent.phone if parent else None,
            first_name=student.first_name,
            last_name=student.last_name,
            photo=student.photo,
            face_encoding=student.face_encoding,
            is_active=student.is_active,
        )
        for student, school_class, parent in rows
    ]


@router.delete(
    "/teachers/{teacher_id}/classes/{assignment_id}",
    dependencies=[Depends(get_current_director)],
)
def director_remove_class_assignment(
    teacher_id: int,
    assignment_id: int,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    _require_teacher(db, teacher_id, director)
    remove_class_assignment(db, teacher_id=teacher_id, assignment_id=assignment_id)
    return {"message": "Assignment removed"}


@router.get(
    "/classes/{class_id}/subjects",
    response_model=list[ClassSubjectResponse],
    dependencies=[Depends(get_current_director)],
)
def director_class_subjects(
    class_id: int,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    school_class = db.query(Class).filter(
        Class.id == class_id,
        Class.school_id == director.school_id,
    ).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Class not found")

    rows = db.query(TeacherClass, Teacher).join(
        Teacher, Teacher.id == TeacherClass.teacher_id
    ).filter(TeacherClass.class_id == class_id).order_by(TeacherClass.subject.asc()).all()

    return [
        ClassSubjectResponse(
            id=assignment.id,
            subject=assignment.subject,
            teacher_id=teacher.id,
            teacher_name=teacher.full_name,
        )
        for assignment, teacher in rows
    ]


@router.delete(
    "/teachers/{teacher_id}",
    dependencies=[Depends(get_current_director)],
)
def director_delete_teacher(
    teacher_id: int,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    teacher = _require_teacher(db, teacher_id, director)

    db.query(Grade).filter(Grade.teacher_id == teacher_id).delete(synchronize_session=False)
    db.query(TeacherClass).filter(TeacherClass.teacher_id == teacher_id).delete(synchronize_session=False)
    # "homework" has no ORM model (the feature was removed from the app) but
    # the table -- and its FK to teachers -- is still in the database on
    # installations that had it. A fresh database never creates it, so guard
    # with to_regclass the same way database.py does for room_positions.
    if db.execute(text("SELECT to_regclass('public.homework')")).scalar():
        db.execute(text("DELETE FROM homework WHERE teacher_id = :teacher_id"), {"teacher_id": teacher_id})
    db.delete(teacher)
    db.commit()
    return {"message": "Teacher deleted"}
