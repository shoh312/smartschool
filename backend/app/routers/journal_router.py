from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy.orm import Session, joinedload

from app.database import get_db
from app.deps import AuthActor, get_current_actor, get_current_teacher
from app.models.class_model import Class
from app.models.journal_model import Grade
from app.models.lesson_attendance_model import LessonAttendance
from app.models.lesson_model import Lesson
from app.models.student import Student
from app.models.teacher_model import Teacher
from app.schemas.journal_schema import GradeCreate, GradeResponse, GradeUpdate
from app.services import analytics_service
from app.services.journal_scan_service import JournalScanError, scan_journal_photo
from app.services.sync_outbox_service import enqueue_grade_event, enqueue_student_analytics_event
from app.services.teacher_service import teacher_can_grade_class
from app.utils.academic_calendar import current_quarter, school_year_for_date

router = APIRouter(tags=["journal"])

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
    if payload.grade_date is not None and payload.grade_date != today:
        raise HTTPException(status_code=400, detail="Grades can only be entered for today")

    grade = Grade(
        student_id=payload.student_id,
        class_id=payload.class_id,
        teacher_id=teacher.id,
        subject=payload.subject,
        quarter=payload.quarter or current_quarter(),
        school_year=school_year_for_date(today),
        value=payload.value,
        comment=payload.comment,
        grade_date=today,
    )
    db.add(grade)
    db.flush()
    enqueue_grade_event(db, grade, operation="upsert")
    _push_student_analytics(db, grade.student_id, grade.quarter, grade.school_year)
    db.commit()
    db.refresh(grade)
    grade.teacher = teacher
    return grade


@router.post("/journal/scan-photo")
async def scan_journal_photo_endpoint(
    class_id: int = Form(...),
    subject: str = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    teacher: Teacher = Depends(get_current_teacher),
):
    if not teacher_can_grade_class(db, teacher.id, class_id, subject):
        raise HTTPException(
            status_code=403,
            detail="You are not assigned to teach this subject in this class",
        )

    roster = [
        (s.id, f"{s.last_name} {s.first_name}".strip())
        for s in db.query(Student).filter(Student.class_id == class_id, Student.is_active == True).all()
    ]

    image_bytes = await file.read()
    try:
        results = scan_journal_photo(image_bytes, file.content_type or "image/jpeg", roster)
    except JournalScanError as exc:
        print(f"[journal-scan] content_type={file.content_type!r} bytes={len(image_bytes)} error={ascii(str(exc))}")
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    print(f"[journal-scan] {len(results)} rows for class_id={class_id} subject={ascii(subject)}:")
    for row in results:
        print(
            f"  raw={ascii(row['raw_name'])} matched={ascii(row['matched_name'])} "
            f"absent={row['absent']} grade={row['grade']}"
        )

    return {"results": results}


def _push_student_analytics(db: Session, student_id: int, quarter: int, school_year: int | None) -> None:
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        return
    overview = analytics_service.build_student_overview(db, student, quarter, school_year)
    enqueue_student_analytics_event(db, student, overview)


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
    else:
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


@router.get("/journal/absences")
def list_absences(
    class_id: int,
    subject: str | None = None,
    db: Session = Depends(get_db),
    actor: AuthActor = Depends(get_current_actor),
):
    if actor.role == "teacher":
        if not teacher_can_grade_class(db, actor.teacher.id, class_id, subject):
            raise HTTPException(
                status_code=403,
                detail="You are not assigned to teach this class",
            )
    elif actor.role == "director":
        school_class = db.query(Class).filter(
            Class.id == class_id,
            Class.school_id == actor.director.school_id,
        ).first()
        if not school_class:
            raise HTTPException(status_code=404, detail="Class not found")
    else:
        raise HTTPException(status_code=403, detail="Not allowed")

    query = (
        db.query(LessonAttendance, Lesson.subject)
        .join(Lesson, Lesson.id == LessonAttendance.lesson_id)
        .filter(
            Lesson.class_id == class_id,
            LessonAttendance.status == "absent",
        )
    )
    if subject is not None:
        query = query.filter(Lesson.subject == subject)

    return [
        {
            "student_id": row.LessonAttendance.student_id,
            "subject": row.subject,
            "date": row.LessonAttendance.attendance_date.isoformat(),
            "lesson_id": row.LessonAttendance.lesson_id,
        }
        for row in query.order_by(LessonAttendance.attendance_date.desc()).limit(2000).all()
    ]


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
    if payload.quarter is not None:
        grade.quarter = payload.quarter

    db.flush()
    enqueue_grade_event(db, grade, operation="upsert")
    _push_student_analytics(db, grade.student_id, grade.quarter, grade.school_year)
    db.commit()
    db.refresh(grade)
    grade.teacher = teacher
    return grade


@router.delete("/grades/{grade_id}", status_code=204)
def delete_grade(
    grade_id: int,
    db: Session = Depends(get_db),
    teacher: Teacher = Depends(get_current_teacher),
):
    grade = _require_own_grade(db, grade_id, teacher)
    enqueue_grade_event(db, grade, operation="delete")
    student_id, quarter, school_year = grade.student_id, grade.quarter, grade.school_year
    db.delete(grade)
    db.flush()
    _push_student_analytics(db, student_id, quarter, school_year)
    db.commit()
