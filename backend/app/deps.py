from dataclasses import dataclass

from fastapi import Depends, Header, HTTPException, WebSocket, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.director_model import Director
from app.models.parent_model import Parent
from app.models.teacher_model import Teacher
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


def get_current_teacher(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> Teacher:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
        )

    payload = decode_jwt_access_token(authorization.split(" ", 1)[1])
    if payload.get("role") != "teacher":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Teacher access required",
        )

    teacher = db.query(Teacher).filter(Teacher.id == int(payload["sub"])).first()
    if not teacher or not teacher.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Teacher not found or inactive",
        )
    return teacher


def get_current_superadmin(
    director: Director = Depends(get_current_director),
) -> Director:
    if not director.is_superadmin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Superadmin access required",
        )
    return director


@dataclass
class AuthActor:
    """A logged-in director, teacher, or parent, whichever the bearer token maps to."""

    role: str
    director: Director | None = None
    parent: Parent | None = None
    teacher: Teacher | None = None


def get_current_actor(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> AuthActor:
    """Accepts a director JWT or a parent HMAC token and returns whichever matched.

    Used by endpoints that both roles legitimately call (e.g. attendance history),
    where authorization to specific rows is enforced by the endpoint itself.
    """
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
        )
    token = authorization.split(" ", 1)[1]

    try:
        payload = decode_jwt_access_token(token)
        if payload.get("role") == "director":
            director = db.query(Director).filter(Director.id == int(payload["sub"])).first()
            if director and director.is_active:
                return AuthActor(role="director", director=director)
        if payload.get("role") == "teacher":
            teacher = db.query(Teacher).filter(Teacher.id == int(payload["sub"])).first()
            if teacher and teacher.is_active:
                return AuthActor(role="teacher", teacher=teacher)
    except HTTPException:
        pass

    try:
        parent_id = verify_access_token(token)
    except HTTPException:
        parent_id = None

    if parent_id is not None:
        parent = db.query(Parent).filter(Parent.id == parent_id).first()
        if parent:
            return AuthActor(role="parent", parent=parent)

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired token",
    )


async def get_current_director_ws(websocket: WebSocket, db: Session = Depends(get_db)) -> Director:
    """Websocket clients can't send custom headers as easily as HTTP clients, so the
    director JWT is passed as a `token` query parameter instead of an Authorization header.
    """
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        raise HTTPException(status_code=401, detail="Missing token")

    try:
        payload = decode_jwt_access_token(token)
        director = None
        if payload.get("role") == "director":
            director = db.query(Director).filter(Director.id == int(payload["sub"])).first()
        if not director or not director.is_active:
            raise HTTPException(status_code=401, detail="Director not found or inactive")
        return director
    except HTTPException:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        raise
