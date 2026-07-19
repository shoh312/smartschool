from fastapi import APIRouter, HTTPException
from sqlalchemy.orm import Session
from fastapi import Depends

from app.database import get_db
from app.deps import get_current_director, get_current_parent
from app.models.class_model import Class
from app.models.director_model import Director
from app.models.parent_model import Parent
from app.models.student import Student
from app.schemas.student_schema import (
    StudentCreate,
    StudentResponse
)
from app.services.auth_service import get_parent_family_ids
from app.services.sync_outbox_service import enqueue_student_event
from app.utils.phone import normalize_phone

from fastapi import Form, UploadFile, File
import shutil
import os

from app.ai.face_engine import (
    generate_face_encoding
)

router = APIRouter(tags=["students"], dependencies=[Depends(get_current_director)])

# A separate router (no director-only dependency) for the parent-facing
# "my children" endpoint -- the main router above requires a director.
parent_router = APIRouter(tags=["students"])


@parent_router.get("/students/me", response_model=list[StudentResponse])
def get_my_students(
    db: Session = Depends(get_db),
    parent: Parent = Depends(get_current_parent),
):
    # A parent with children at two different schools has a sibling Parent
    # row per school sharing the same phone -- return every school's
    # children, not just the ones under this exact logged-in row.
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
        }
        for student, school_class in rows
    ]

# ==================================================
# CREATE STUDENT
# ==================================================

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

# ==================================================
# GET STUDENTS
# ==================================================

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

    # Scope the lookup to this school -- a phone match belonging to a
    # different school must not be reused, or a new student here would get
    # silently attached to another school's parent account (and its
    # /students/me would start returning both schools' children mixed
    # together).
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

    db.flush()
    # Sync the enrollment now (not only on the first grade/attendance event)
    # so the parent can log into the Public Server the same day.
    enqueue_student_event(db, new_student, operation="upsert")

    db.commit()

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
    parent_phone: str = Form(...),
    is_active: bool = Form(True),
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

    # Handle parent -- scoped to this school, see director_create_student for why.
    normalized_phone = normalize_phone(parent_phone)
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

    student.first_name = first_name.strip()
    student.last_name = last_name.strip()
    student.class_id = class_id
    student.parent_id = parent.id
    student.is_active = is_active

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
        "parent_phone": parent.phone,
        "parent_name": parent.full_name,
        "first_name": student.first_name,
        "last_name": student.last_name,
        "photo": student.photo,
        "face_encoding": student.face_encoding,
        "is_active": student.is_active,
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
    
    # Explicitly delete associated records in correct order to avoid FK violations
    from app.models.attendance_model import Attendance
    from app.models.notification_model import NotificationEvent
    from app.models.journal_model import Grade

    # 1. Delete notifications related to the student's attendances
    attendance_ids = [a.id for a in db.query(Attendance).filter(Attendance.student_id == student_id).all()]
    if attendance_ids:
        db.query(NotificationEvent).filter(NotificationEvent.attendance_id.in_(attendance_ids)).delete(synchronize_session=False)

    # 2. Delete notifications directly related to the student
    db.query(NotificationEvent).filter(NotificationEvent.student_id == student_id).delete(synchronize_session=False)

    # 3. Delete attendance records
    db.query(Attendance).filter(Attendance.student_id == student_id).delete(synchronize_session=False)

    # 4. Delete grades entered for this student
    db.query(Grade).filter(Grade.student_id == student_id).delete(synchronize_session=False)

    # 5. Tell the Public Server this student is gone -- deactivate, not a
    # hard delete, so history already synced (old grades/attendance) doesn't
    # vanish retroactively from the parent's view.
    enqueue_student_event(db, student, operation="deactivate")

    # 6. Delete the student
    db.delete(student)
    db.commit()
    return {"message": "Student deleted"}
