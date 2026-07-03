from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.director_model import Director
from app.models.parent_model import Parent
from app.services.auth_service import verify_access_token
from app.utils.security import decode_jwt_access_token


def get_current_parent(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> Parent:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")

    parent_id = verify_access_token(authorization.split(" ", 1)[1])
    parent = db.query(Parent).filter(Parent.id == parent_id).first()
    if not parent:
        raise HTTPException(status_code=401, detail="Parent not found")
    return parent


def get_current_director(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> Director:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
        )

    payload = decode_jwt_access_token(authorization.split(" ", 1)[1])
    if payload.get("role") != "director":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Director access required",
        )

    director = db.query(Director).filter(Director.id == int(payload["sub"])).first()
    if not director or not director.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Director not found or inactive",
        )
    return director
