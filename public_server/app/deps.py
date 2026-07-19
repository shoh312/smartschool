from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.parent_model import Parent
from app.models.school_model import School
from app.utils.security import verify_parent_access_token, verify_school_key


def get_current_parent(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> Parent:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")

    parent_id = verify_parent_access_token(authorization.split(" ", 1)[1])
    parent = db.query(Parent).filter(Parent.id == parent_id).first()
    if not parent:
        raise HTTPException(status_code=401, detail="Parent not found")
    return parent


def get_current_school(
    x_school_key: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> School:
    if not x_school_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing X-School-Key"
        )

    # api_key_hash is per-school, so every active school must be checked
    # (there's no lookup-by-key column -- the raw key is never stored).
    for school in db.query(School).filter(School.is_active == True).all():
        if verify_school_key(x_school_key, school.api_key_hash):
            return school

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid school key"
    )
