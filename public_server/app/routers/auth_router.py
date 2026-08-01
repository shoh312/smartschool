from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.parent_model import Parent
from app.schemas.auth_schema import LoginRequest
from app.utils.phone import normalize_phone
from app.utils.security import create_parent_access_token

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
