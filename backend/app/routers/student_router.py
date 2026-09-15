import logging

from fastapi import APIRouter, HTTPException
from sqlalchemy.orm import Session
from fastapi import Depends

from app.database import get_db
from app.deps import get_current_director, get_current_parent
from app.models.class_model import Class
from app.models.director_model import Director
from app.models.parent_model import Parent
from app.models.school_model import School
from app.models.student import Student
from app.schemas.student_schema import (
    StudentCreate,
    StudentResponse
)
from app.services.auth_service import get_parent_family_ids
from app.services.credentials_service import send_credentials_notification
from app.services.robita_sms import client as robita_client, to_local_number
from app.services.student_login_service import issue_login_for, issue_logins
from app.services.sync_outbox_service import enqueue_student_event
from app.utils.config import settings
from app.utils.phone import normalize_phone
from app.utils.security import generate_password, hash_student_password

from fastapi import Form, UploadFile, File
import shutil
import os

from app.ai.face_engine import (
    generate_face_encoding
)

logger = logging.getLogger(__name__)

router = APIRouter(tags=["students"], dependencies=[Depends(get_current_director)])

parent_router = APIRouter(tags=["students"])


@parent_router.get("/students/me", response_model=list[StudentResponse])
def get_my_students(
    db: Session = Depends(get_db),
    parent: Parent = Depends(get_current_parent),
):
    family_ids = get_parent_family_ids(db, parent)

    rows = db.query(Student, Class).filter(
        Student.parent_id.in_(family_ids)
    ).outerjoin(
        Class,
        Student.class_id == Class.id
    ).order_by(Student.id.desc()).all()

    return [
        {
            "id": student.id,
            "class_id": student.class_id,
            "parent_id": student.parent_id,
            "class_name": school_class.name if school_class else None,
            "parent_phone": parent.phone,
            "parent_name": parent.full_name,
            "first_name": student.first_name,
            "last_name": student.last_name,
            "photo": student.photo,
            "face_encoding": student.face_encoding,
            "is_active": student.is_active,
            "username": student.username,
        }
        for student, school_class in rows
    ]


def _claim_username(db: Session, value: str, student_id: int | None = None) -> str:
    candidate = value.strip()
    clash = db.query(Student).filter(Student.username == candidate)
    if student_id is not None:
        clash = clash.filter(Student.id != student_id)
    if clash.first():
        raise HTTPException(status_code=409, detail="username_taken")
    return candidate


@router.post("/students")

def create_student(
    student: StudentCreate,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):

    new_student = Student(

        school_id=director.school_id,

        class_id=student.class_id,

        parent_id=student.parent_id,

        first_name=student.first_name,

        last_name=student.last_name,

        photo=student.photo,

        face_encoding=student.face_encoding
    )

    db.add(new_student)

    db.commit()

    db.refresh(new_student)

    return new_student


@router.get(
    "/students",
    response_model=list[StudentResponse]
)

def get_students(
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):

    rows = db.query(Student, Class, Parent).filter(
        Student.school_id == director.school_id
    ).outerjoin(
        Class,
        Student.class_id == Class.id
    ).outerjoin(
        Parent,
        Student.parent_id == Parent.id
    ).order_by(Student.id.desc()).all()

    students = []

    for student, school_class, parent in rows:

        students.append({
            "id": student.id,
            "class_id": student.class_id,
            "parent_id": student.parent_id,
            "class_name": school_class.name if school_class else None,
            "parent_phone": parent.phone if parent else None,
            "parent_name": parent.full_name if parent else None,
            "first_name": student.first_name,
            "last_name": student.last_name,
            "photo": student.photo,
            "face_encoding": student.face_encoding,
            "is_active": student.is_active,
            "username": student.username,
        })

    return students


@router.post(
    "/students/director-create",
    response_model=StudentResponse
)
def director_create_student(
    first_name: str = Form(...),
    last_name: str = Form(...),
    class_id: int = Form(...),
    parent_phone: str = Form(...),
    parent_full_name: str | None = Form(None),
    username: str | None = Form(None),
    password: str | None = Form(None),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):

    school_class = db.query(Class).filter(
        Class.id == class_id,
        Class.school_id == director.school_id,
    ).first()

    if not school_class:

        raise HTTPException(status_code=404, detail="Class not found")

    normalized_phone = normalize_phone(parent_phone)

    if not normalized_phone:

        raise HTTPException(status_code=400, detail="Parent phone is required")

    parent = db.query(Parent).filter(
        Parent.phone == normalized_phone,
        Parent.school_id == director.school_id,
    ).first()

    if not parent:

        parent = Parent(
            school_id=director.school_id,
            full_name=parent_full_name or normalized_phone,
            phone=normalized_phone
        )

        db.add(parent)

        db.commit()

        db.refresh(parent)

    parent_plaintext_password = None

    if not parent.password_hash:

        parent_plaintext_password = generate_password()

        parent.password_salt, parent.password_hash = hash_student_password(
            parent_plaintext_password
        )

        db.commit()

    os.makedirs("uploads", exist_ok=True)

    extension = os.path.splitext(file.filename or "")[1] or ".jpg"

    new_student = Student(
        school_id=director.school_id,
        class_id=school_class.id,
        parent_id=parent.id,
        first_name=first_name.strip(),
        last_name=last_name.strip(),
        is_active=True
    )

    if username and username.strip():
        new_student.username = _claim_username(db, username)

    db.add(new_student)

    db.commit()

    db.refresh(new_student)

    file_path = f"uploads/{new_student.id}{extension}"

    with open(file_path, "wb") as buffer:

        shutil.copyfileobj(
            file.file,
            buffer
        )

    encoding = generate_face_encoding(
        file_path
    )

    if not encoding:

        db.delete(new_student)

        db.commit()

        raise HTTPException(status_code=400, detail="Face not detected")

    new_student.photo = file_path

    new_student.face_encoding = encoding

    student_username, student_password = issue_login_for(db, new_student, password)

    db.flush()
    enqueue_student_event(db, new_student, operation="upsert")

    db.commit()

    send_credentials_notification(
        parent=parent,
        student=new_student,
        student_username=student_username,
        student_password=student_password,
    )

    school = db.query(School).filter(School.id == director.school_id).first()
    if parent_plaintext_password and settings.sms_provider == "robita" and school is not None and school.sms_enabled:
        school_name = school.name if school else "SmartFlow"
        message = (
            "SmartFlow: фарзандатон %s %s ба мактаби «%s» сабти ном шуд.\n"
            "Шумо: логин %s, парол: %s\n"
            "Фарзанд: логин %s, парол: %s"
            % (
                new_student.first_name,
                new_student.last_name,
                school_name,
                parent.phone,
                parent_plaintext_password,
                student_username,
                student_password,
            )
        )
        try:
            robita_client.send(to_local_number(parent.phone), message)
        except Exception:
            logger.exception("Robita SMS failed for new parent %s", parent.id)

    db.refresh(new_student)

    return {
        "id": new_student.id,
        "class_id": new_student.class_id,
        "parent_id": new_student.parent_id,
        "class_name": school_class.name,
        "parent_phone": parent.phone,
        "parent_name": parent.full_name,
        "first_name": new_student.first_name,
        "last_name": new_student.last_name,
        "photo": new_student.photo,
        "face_encoding": new_student.face_encoding,
        "is_active": new_student.is_active,
        "username": new_student.username,
    }


@router.post("/students/register-face/{student_id}")

def register_face(
    student_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):

    student = db.query(Student).filter(
        Student.id == student_id,
        Student.school_id == director.school_id,
    ).first()

    if not student:

        raise HTTPException(status_code=404, detail="Student not found")

    os.makedirs("uploads", exist_ok=True)

    file_path = f"uploads/{student_id}.jpg"

    with open(file_path, "wb") as buffer:

        shutil.copyfileobj(
            file.file,
            buffer
        )

    encoding = generate_face_encoding(
        file_path
    )

    if not encoding:

        raise HTTPException(status_code=400, detail="Face not detected")

    student.photo = file_path

    student.face_encoding = encoding

    db.commit()

    return {
        "message": "Face registered"
    }


@router.put("/students/{student_id}", response_model=StudentResponse)
def update_student(
    student_id: int,
    first_name: str = Form(...),
    last_name: str = Form(...),
    class_id: int = Form(...),
    parent_phone: str | None = Form(None),
    is_active: bool = Form(True),
    username: str | None = Form(None),
    password: str | None = Form(None),
    file: UploadFile | None = File(None),
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    student = db.query(Student).filter(
        Student.id == student_id,
        Student.school_id == director.school_id,
    ).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    school_class = db.query(Class).filter(
        Class.id == class_id,
        Class.school_id == director.school_id,
    ).first()
    if not school_class:
        raise HTTPException(status_code=404, detail="Class not found")

    normalized_phone = normalize_phone(parent_phone) if parent_phone else ""
    parent = None
    if normalized_phone:
        parent = db.query(Parent).filter(
            Parent.phone == normalized_phone,
            Parent.school_id == director.school_id,
        ).first()
        if not parent:
            parent = Parent(
                school_id=director.school_id,
                full_name=normalized_phone,
                phone=normalized_phone,
            )
            db.add(parent)
            db.commit()
            db.refresh(parent)
    elif student.parent_id is not None:
        parent = db.query(Parent).filter(Parent.id == student.parent_id).first()

    student.first_name = first_name.strip()
    student.last_name = last_name.strip()
    student.class_id = class_id
    if parent is not None:
        student.parent_id = parent.id
    student.is_active = is_active

    if username is not None:
        student.username = (
            _claim_username(db, username, student_id=student.id)
            if username.strip() else None
        )
    if password:
        student.password_salt, student.password_hash = hash_student_password(password)

    if file:
        os.makedirs("uploads", exist_ok=True)
        extension = os.path.splitext(file.filename or "")[1] or ".jpg"
        file_path = f"uploads/{student.id}{extension}"
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        encoding = generate_face_encoding(file_path)
        if encoding:
            student.photo = file_path
            student.face_encoding = encoding

    db.flush()
    enqueue_student_event(db, student, operation="upsert")
    db.commit()
    db.refresh(student)

    return {
        "id": student.id,
        "class_id": student.class_id,
        "parent_id": student.parent_id,
        "class_name": school_class.name,
        "parent_phone": parent.phone if parent else None,
        "parent_name": parent.full_name if parent else None,
        "first_name": student.first_name,
        "last_name": student.last_name,
        "photo": student.photo,
        "face_encoding": student.face_encoding,
        "is_active": student.is_active,
        "username": student.username,
    }


@router.delete("/students/{student_id}")
def delete_student(
    student_id: int,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    student = db.query(Student).filter(
        Student.id == student_id,
        Student.school_id == director.school_id,
    ).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    from app.models.attendance_model import Attendance
    from app.models.notification_model import NotificationEvent
    from app.models.journal_model import Grade
    from app.models.lesson_attendance_model import LessonAttendance
    from app.models.material_model import MaterialAttempt

    attendance_ids = [a.id for a in db.query(Attendance).filter(Attendance.student_id == student_id).all()]
    if attendance_ids:
        db.query(NotificationEvent).filter(NotificationEvent.attendance_id.in_(attendance_ids)).delete(synchronize_session=False)

    db.query(NotificationEvent).filter(NotificationEvent.student_id == student_id).delete(synchronize_session=False)

    db.query(Attendance).filter(Attendance.student_id == student_id).delete(synchronize_session=False)

    db.query(Grade).filter(Grade.student_id == student_id).delete(synchronize_session=False)

    db.query(LessonAttendance).filter(LessonAttendance.student_id == student_id).delete(synchronize_session=False)
    db.query(MaterialAttempt).filter(MaterialAttempt.student_id == student_id).delete(synchronize_session=False)

    enqueue_student_event(db, student, operation="deactivate")

    photo_path = student.photo
    db.delete(student)
    db.commit()

    if photo_path and os.path.exists(photo_path):
        os.remove(photo_path)

    return {"message": "Student deleted"}


@router.post("/students/issue-logins")
def issue_student_logins(
    class_id: int | None = None,
    reset_existing: bool = False,
    db: Session = Depends(get_db),
    director: Director = Depends(get_current_director),
):
    query = db.query(Student).filter(
        Student.school_id == director.school_id,
        Student.is_active == True,
    )
    if class_id is not None:
        school_class = db.query(Class).filter(
            Class.id == class_id,
            Class.school_id == director.school_id,
        ).first()
        if not school_class:
            raise HTTPException(status_code=404, detail="Class not found")
        query = query.filter(Student.class_id == class_id)

    students = query.order_by(Student.last_name, Student.first_name).all()
    issued = issue_logins(db, students, reset_existing=reset_existing)

    db.flush()
    for row in issued:
        student = next(s for s in students if s.id == row["student_id"])
        enqueue_student_event(db, student, operation="upsert")
    db.commit()

    return {
        "issued_count": len(issued),
        "skipped_count": len(students) - len(issued),
        "logins": issued,
    }
