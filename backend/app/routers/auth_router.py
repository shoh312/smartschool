from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_director
from app.models.director_model import Director
from app.schemas.auth_schema import (
    DirectorCreate,
    DirectorLogin,
    DirectorResponse,
    LoginRequest,
    LoginResponse,
    TokenResponse,
    ParentRegisterRequest,
)
from app.services.auth_service import (
    authenticate_director,
    create_director,
    create_director_token,
    login_parent,
    check_or_register_parent,
    complete_parent_registration,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login")
def login(payload: LoginRequest, db: Session = Depends(get_db)):
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
    )


@router.get("/me", response_model=DirectorResponse)
def auth_me(current_director: Director = Depends(get_current_director)):
    return current_director
