from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_director, get_current_teacher
from app.models.class_model import Class
from app.models.director_model import Director
from app.models.parent_model import Parent
from app.models.student import Student
from app.models.teacher_model import Teacher, TeacherClass
from app.schemas.student_schema import StudentResponse
from app.schemas.teacher_schema import (
    ClassAssignmentCreate,
    ClassAssignmentResponse,
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
    teacher_can_grade_class,
)

router = APIRouter(tags=["teachers"])


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
    )


@router.get(
    "/teachers",
    response_model=list[TeacherResponse],
    dependencies=[Depends(get_current_director)],
)
def list_teachers(
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    return db.query(Teacher).filter(
        Teacher.school_id == director.school_id
    ).order_by(Teacher.full_name.asc()).all()


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
