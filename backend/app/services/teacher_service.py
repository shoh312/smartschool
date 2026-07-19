from fastapi import HTTPException, status
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.models.class_model import Class
from app.models.teacher_model import Teacher, TeacherClass
from app.utils.security import create_jwt_access_token, hash_password, verify_password


def create_teacher(
    db: Session,
    school_id: int | None,
    full_name: str,
    email: str,
    password: str,
    subject: str | None = None,
) -> Teacher:
    existing = db.query(Teacher).filter(Teacher.email == email.lower()).first()
    if existing:
        raise HTTPException(status_code=409, detail="Teacher email already exists")

    teacher = Teacher(
        school_id=school_id,
        full_name=full_name,
        email=email.lower(),
        subject=subject,
        hashed_password=hash_password(password),
        is_active=True,
    )
    db.add(teacher)
    db.commit()
    db.refresh(teacher)
    return teacher


def authenticate_teacher(db: Session, email: str, password: str) -> Teacher:
    teacher = db.query(Teacher).filter(Teacher.email == email.lower()).first()
    if not teacher or not verify_password(password, teacher.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    if not teacher.is_active:
        raise HTTPException(status_code=403, detail="Teacher account is inactive")
    return teacher


def create_teacher_token(teacher: Teacher) -> str:
    return create_jwt_access_token(
        subject=str(teacher.id),
        claims={
            "role": "teacher",
            "email": teacher.email,
            "school_id": teacher.school_id,
        },
    )


def assign_class(db: Session, teacher: Teacher, class_id: int, subject: str, school_id: int | None) -> TeacherClass:
    school_class = db.query(Class).filter(
        Class.id == class_id,
        Class.school_id == school_id,
    ).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Class not found")

    existing = db.query(TeacherClass).filter(
        TeacherClass.teacher_id == teacher.id,
        TeacherClass.class_id == class_id,
        TeacherClass.subject == subject,
    ).first()
    if existing:
        return existing

    assignment = TeacherClass(teacher_id=teacher.id, class_id=class_id, subject=subject)
    db.add(assignment)
    db.commit()
    db.refresh(assignment)
    return assignment


def remove_class_assignment(db: Session, teacher_id: int, assignment_id: int) -> None:
    assignment = db.query(TeacherClass).filter(
        TeacherClass.id == assignment_id,
        TeacherClass.teacher_id == teacher_id,
    ).first()
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")

    db.delete(assignment)
    db.commit()


def teacher_class_ids(db: Session, teacher_id: int) -> list[int]:
    rows = db.query(TeacherClass.class_id).filter(TeacherClass.teacher_id == teacher_id).all()
    return [row[0] for row in rows]


def teacher_can_grade_class(
    db: Session, teacher_id: int, class_id: int, subject: str | None = None
) -> bool:
    query = db.query(TeacherClass).filter(
        TeacherClass.teacher_id == teacher_id, TeacherClass.class_id == class_id
    )
    if subject:
        # An assignment row with no subject set is unrestricted (matches any
        # subject). Without the `.is_(None)` branch, a NULL-subject row would
        # never match a caller asking for a specific subject -- SQL NULL is
        # never equal to anything, not even another NULL -- silently locking
        # that teacher out of grading.
        query = query.filter(
            or_(TeacherClass.subject == subject, TeacherClass.subject.is_(None))
        )
    return query.first() is not None
