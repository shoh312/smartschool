from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload

from app.database import get_db
from app.deps import AuthActor, get_current_actor, get_current_teacher
from app.models.journal_model import Grade
from app.models.student import Student
from app.models.teacher_model import Teacher
from app.schemas.journal_schema import GradeCreate, GradeResponse, GradeUpdate
from app.services.teacher_service import teacher_can_grade_class

router = APIRouter(tags=["journal"])

# Grades are entered live during the school day, so "today" must be judged in
# the school's local time (Tajikistan, UTC+5, no DST) rather than the server
# machine's own clock/timezone -- otherwise a UTC-hosted server disagrees
# with the classroom about which calendar day it is near local midnight, and
# a grade entered minutes ago becomes immediately uneditable (or a grade
# entered near midnight the previous UTC day looks "not from today").
SCHOOL_TZ = timezone(timedelta(hours=5))


def _school_today():
    return datetime.now(SCHOOL_TZ).date()


def _require_student_in_class(db: Session, student_id: int, class_id: int) -> Student:
    student = db.query(Student).filter(
        Student.id == student_id,
        Student.class_id == class_id,
    ).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found in that class")
    return student


def _require_own_grade(db: Session, grade_id: int, teacher: Teacher) -> Grade:
    grade = db.query(Grade).filter(Grade.id == grade_id).first()
    if not grade:
        raise HTTPException(status_code=404, detail="Grade not found")
    if grade.teacher_id != teacher.id:
        raise HTTPException(status_code=403, detail="You did not enter this grade")
    if grade.grade_date != _school_today():
        raise HTTPException(status_code=403, detail="Only today's grades can be edited")
    if not teacher_can_grade_class(db, teacher.id, grade.class_id, grade.subject):
        raise HTTPException(
            status_code=403,
            detail="You are no longer assigned to teach this subject in this class",
        )
    return grade


@router.post("/grades", response_model=GradeResponse)
def create_grade(
    payload: GradeCreate,
    db: Session = Depends(get_db),
    teacher: Teacher = Depends(get_current_teacher),
):
    if not teacher_can_grade_class(db, teacher.id, payload.class_id, payload.subject):
        raise HTTPException(
            status_code=403,
            detail="You are not assigned to teach this subject in this class",
        )

    _require_student_in_class(db, payload.student_id, payload.class_id)

    today = _school_today()
    # A grade dated anything other than today would fail the same
    # today-only check the moment it's read back in _require_own_grade,
    # permanently locking it from its own creator. Reject it up front
    # instead of silently creating an uneditable grade.
    if payload.grade_date is not None and payload.grade_date != today:
        raise HTTPException(status_code=400, detail="Grades can only be entered for today")

    grade = Grade(
        student_id=payload.student_id,
        class_id=payload.class_id,
        teacher_id=teacher.id,
        subject=payload.subject,
        value=payload.value,
        comment=payload.comment,
        grade_date=today,
    )
    db.add(grade)
    db.commit()
    db.refresh(grade)
    return grade


@router.get("/grades", response_model=list[GradeResponse])
def list_grades(
    student_id: int | None = None,
    class_id: int | None = None,
    subject: str | None = None,
    limit: int = 200,
    db: Session = Depends(get_db),
    actor: AuthActor = Depends(get_current_actor),
):
    query = db.query(Grade).options(joinedload(Grade.teacher))

    if actor.role == "parent":
        if student_id is not None:
            student = db.query(Student).filter(Student.id == student_id).first()
            if not student or student.parent_id not in actor.parent_ids:
                raise HTTPException(status_code=403, detail="Not your student")
            query = query.filter(Grade.student_id == student_id)
        else:
            query = query.join(Student, Student.id == Grade.student_id).filter(
                Student.parent_id.in_(actor.parent_ids)
            )
    elif actor.role == "teacher":
        if class_id is not None:
            # A teacher currently assigned to this class (and subject, if
            # given) should see every grade recorded for it, not only the
            # ones they personally entered -- otherwise grades appear to
            # "disappear" from the roster view after a mid-term teacher
            # reassignment, even though the director still sees them all.
            if not teacher_can_grade_class(db, actor.teacher.id, class_id, subject):
                raise HTTPException(
                    status_code=403,
                    detail="You are not assigned to teach this class",
                )
            query = query.filter(Grade.class_id == class_id)
            if student_id is not None:
                query = query.filter(Grade.student_id == student_id)
        else:
            query = query.filter(Grade.teacher_id == actor.teacher.id)
            if student_id is not None:
                query = query.filter(Grade.student_id == student_id)
    else:  # director
        query = query.join(Student, Student.id == Grade.student_id).filter(
            Student.school_id == actor.director.school_id
        )
        if student_id is not None:
            query = query.filter(Grade.student_id == student_id)
        if class_id is not None:
            query = query.filter(Grade.class_id == class_id)

    if subject is not None:
        query = query.filter(Grade.subject == subject)

    return query.order_by(Grade.grade_date.desc(), Grade.id.desc()).limit(limit).all()


@router.patch("/grades/{grade_id}", response_model=GradeResponse)
def update_grade(
    grade_id: int,
    payload: GradeUpdate,
    db: Session = Depends(get_db),
    teacher: Teacher = Depends(get_current_teacher),
):
    grade = _require_own_grade(db, grade_id, teacher)

    if payload.value is not None:
        grade.value = payload.value
    if payload.comment is not None:
        grade.comment = payload.comment
    if payload.grade_date is not None:
        grade.grade_date = payload.grade_date

    db.commit()
    db.refresh(grade)
    return grade


@router.delete("/grades/{grade_id}", status_code=204)
def delete_grade(
    grade_id: int,
    db: Session = Depends(get_db),
    teacher: Teacher = Depends(get_current_teacher),
):
    grade = _require_own_grade(db, grade_id, teacher)
    db.delete(grade)
    db.commit()
