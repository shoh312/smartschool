from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.parent_model import Parent
from app.models.student_model import Student
from app.schemas.auth_schema import LoginRequest, StudentLoginRequest
from app.utils.phone import normalize_phone
from app.utils.security import create_parent_access_token, create_student_access_token, verify_student_password

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login")
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    normalized = normalize_phone(payload.phone)
    parent = db.query(Parent).filter(Parent.phone == normalized).first()

    if not parent:
        # No self-registration here (unlike the local server): a parent
        # identity can only originate from a director creating a student
        # locally, which then syncs in. An unknown phone means no school has
        # registered it yet.
        raise HTTPException(
            status_code=404,
            detail="phone_not_registered",
        )

    return {
        "status": "login",
        "access_token": create_parent_access_token(parent.id),
        "parent_id": parent.id,
        "full_name": parent.full_name,
        "phone": parent.phone,
    }


@router.post("/student/login")
def student_login(payload: StudentLoginRequest, db: Session = Depends(get_db)):
    student = db.query(Student).filter(Student.username == payload.username).first()

    # Same generic message whether the username doesn't exist, has no
    # password set, or the password is wrong -- don't let a caller probe
    # which usernames exist.
    invalid = HTTPException(status_code=401, detail="invalid_credentials")
    if not student or not student.password_hash or not student.password_salt:
        raise invalid
    if not verify_student_password(payload.password, student.password_salt, student.password_hash):
        raise invalid
    if not student.is_active:
        raise invalid

    return {
        "status": "login",
        "access_token": create_student_access_token(student.id),
        "student_id": student.id,
        "full_name": f"{student.first_name} {student.last_name}".strip(),
        "class_name": student.class_name,
    }
