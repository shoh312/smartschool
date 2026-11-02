from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_director, get_current_superadmin
from app.models.director_model import Director
from app.models.teacher_model import Teacher
from app.schemas.teacher_schema import TeacherResponse
from app.services.teacher_service import create_teacher_token
from app.utils.login_guard import check_login_allowed, clear_login_failures, record_login_failure
from app.utils.security import verify_password
from app.schemas.auth_schema import (
    DirectorChangePassword,
    DirectorCreate,
    DirectorLogin,
    DirectorResponse,
    LoginRequest,
    LoginResponse,
    TokenResponse,
    ParentRegisterRequest,
)
from app.utils.config import settings
from app.services.auth_service import (
    authenticate_director,
    change_director_password,
    create_director,
    create_director_token,
    login_parent,
    check_or_register_parent,
    complete_parent_registration,
)

router = APIRouter(prefix="/auth", tags=["auth"])


def _require_legacy_parent_login() -> None:
    # Phone number alone is not proof of identity, so these stay closed
    # unless LEGACY_PARENT_LOGIN=1 is set for an offline LAN-only install.
    if not settings.legacy_parent_login:
        raise HTTPException(status_code=404, detail="Not Found")


@router.post("/login")
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    _require_legacy_parent_login()
    result = check_or_register_parent(db, phone=payload.phone)
    if result["status"] == "register":
        return {"status": "register"}
    
    parent, token = login_parent(
        db,
        phone=payload.phone,
        firebase_token=payload.firebase_token,
        platform=payload.platform,
    )
    return {
        "status": "login",
        "access_token": token,
        "parent_id": parent.id,
        "full_name": parent.full_name,
        "phone": parent.phone,
    }

@router.post("/register/complete")
def register_complete(payload: ParentRegisterRequest, db: Session = Depends(get_db)):
    _require_legacy_parent_login()
    parent, token = complete_parent_registration(
        db,
        phone=payload.phone,
        full_name=payload.full_name,
        firebase_token=payload.firebase_token,
        platform=payload.platform,
    )
    return {
        "access_token": token,
        "parent_id": parent.id,
        "full_name": parent.full_name,
        "phone": parent.phone,
    }


@router.post("/director/create", response_model=DirectorResponse)
def create_director_account(
    payload: DirectorCreate,
    db: Session = Depends(get_db),
    _current_superadmin: Director = Depends(get_current_superadmin),
):
    return create_director(
        db,
        full_name=payload.full_name,
        email=str(payload.email),
        password=payload.password,
        school_id=payload.school_id,
    )


@router.post("/director/login", response_model=TokenResponse)
def login_director(
    payload: DirectorLogin,
    db: Session = Depends(get_db),
):
    director = authenticate_director(
        db,
        email=str(payload.email),
        password=payload.password,
    )
    return TokenResponse(
        access_token=create_director_token(director),
        user_type="director",
        director=director,
        must_change_password=bool(director.must_change_password),
    )


@router.get("/me", response_model=DirectorResponse)
def auth_me(current_director: Director = Depends(get_current_director)):
    return current_director


@router.post("/director/change-password")
def change_password(
    payload: DirectorChangePassword,
    db: Session = Depends(get_db),
    current_director: Director = Depends(get_current_director),
):
    change_director_password(
        db,
        current_director,
        current_password=payload.current_password,
        new_password=payload.new_password,
    )
    return {"message": "Password updated"}


class StaffLoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_type: str
    director: Optional[DirectorResponse] = None
    teacher: Optional[TeacherResponse] = None
    must_change_password: bool = False


@router.post("/staff/login", response_model=StaffLoginResponse)
def login_staff(payload: DirectorLogin, db: Session = Depends(get_db)):
    """One sign-in for the school's staff: the login page no longer asks
    "director or teacher?" -- the email decides. Directors are checked first."""
    email = str(payload.email).strip().lower()
    guard_key = "staff:" + email
    check_login_allowed(guard_key)

    director = db.query(Director).filter(Director.email == email).first()
    if director and verify_password(payload.password, director.hashed_password):
        if not director.is_active:
            raise HTTPException(status_code=403, detail="account_inactive")
        clear_login_failures(guard_key)
        return StaffLoginResponse(
            access_token=create_director_token(director),
            user_type="director",
            director=director,
            must_change_password=bool(director.must_change_password),
        )

    teacher = db.query(Teacher).filter(Teacher.email == email).first()
    if teacher and verify_password(payload.password, teacher.hashed_password):
        if not teacher.is_active:
            raise HTTPException(status_code=403, detail="account_inactive")
        clear_login_failures(guard_key)
        return StaffLoginResponse(
            access_token=create_teacher_token(teacher),
            user_type="teacher",
            teacher=teacher,
        )

    record_login_failure(guard_key)
    raise HTTPException(status_code=401, detail="invalid_credentials")
