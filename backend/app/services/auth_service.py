import base64
import hashlib
import hmac
import json
from datetime import datetime, timedelta

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.director_model import Director
from app.models.notification_model import DeviceToken
from app.models.parent_model import Parent
from app.utils.config import settings
from app.utils.phone import normalize_phone
from app.utils.security import (
    create_jwt_access_token,
    hash_password,
    verify_password,
)

DEFAULT_DIRECTOR_EMAIL = "director@smartschool.com"
DEFAULT_DIRECTOR_PASSWORD = "12345678"


def _sign(payload: str) -> str:
    return hmac.new(
        settings.auth_secret.encode("utf-8"),
        payload.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def create_access_token(parent_id: int) -> str:
    payload = {
        "parent_id": parent_id,
        "exp": (datetime.utcnow() + timedelta(days=30)).isoformat(),
    }
    payload_text = json.dumps(payload, separators=(",", ":"))
    encoded = base64.urlsafe_b64encode(payload_text.encode("utf-8")).decode("utf-8")
    return f"{encoded}.{_sign(encoded)}"


def verify_access_token(token: str) -> int:
    try:
        encoded, signature = token.split(".", 1)
        if not hmac.compare_digest(signature, _sign(encoded)):
            raise ValueError
        payload = json.loads(base64.urlsafe_b64decode(encoded.encode("utf-8")))
        if datetime.fromisoformat(payload["exp"]) < datetime.utcnow():
            raise ValueError
        return int(payload["parent_id"])
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        ) from exc


def get_parent_family_ids(db: Session, parent: Parent) -> list[int]:
    """All Parent rows sharing this parent's phone number, across every school.

    A parent's phone is the only login credential, and Parent rows are scoped
    one-per-school (see student_router.py's director_create_student), so a
    parent with children at two different schools ends up with two separate
    Parent rows sharing the same phone. Anywhere that authorizes or fetches
    "this parent's own data" (students, grades, attendance, notifications)
    should check/query against this whole set, not a single parent.id, or a
    multi-school parent only ever sees one school's worth of data.
    """
    rows = db.query(Parent.id).filter(Parent.phone == parent.phone).all()
    return [row[0] for row in rows]


def login_parent(db: Session, phone: str, firebase_token: str | None, platform: str | None):
    # NOTE: parent login is phone-only with no school selection step, and
    # Parent.phone is now scoped per-school at creation time (see
    # student_router.py), so a parent with children in two different schools
    # ends up with two separate Parent rows sharing the same phone. This
    # `.first()` only surfaces one of them -- a known limitation, not a
    # cross-school data leak (each row still only sees its own school's
    # students). A real fix needs a school-selection step in the login flow.
    parent = db.query(Parent).filter(Parent.phone == normalize_phone(phone)).first()
    if not parent:
        raise HTTPException(status_code=404, detail="Parent not found")

    if firebase_token:
        parent.firebase_token = firebase_token
        token = db.query(DeviceToken).filter(DeviceToken.token == firebase_token).first()
        if token:
            token.parent_id = parent.id
            token.platform = platform
            token.is_active = True
        else:
            db.add(DeviceToken(parent_id=parent.id, token=firebase_token, platform=platform))
        db.commit()
        db.refresh(parent)

    return parent, create_access_token(parent.id)


def check_or_register_parent(db: Session, phone: str):
    parent = db.query(Parent).filter(Parent.phone == normalize_phone(phone)).first()
    if parent:
        return {"status": "login", "parent_id": parent.id}
    return {"status": "register"}


def complete_parent_registration(db: Session, phone: str, full_name: str, firebase_token: str | None, platform: str | None):
    parent = Parent(phone=normalize_phone(phone), full_name=full_name)
    db.add(parent)
    db.commit()
    db.refresh(parent)
    
    if firebase_token:
        db.add(DeviceToken(parent_id=parent.id, token=firebase_token, platform=platform))
        db.commit()
        
    return parent, create_access_token(parent.id)


def create_director(
    db: Session,
    full_name: str,
    email: str,
    password: str,
    school_id: int | None = None,
) -> Director:
    existing = db.query(Director).filter(Director.email == email.lower()).first()
    if existing:
        raise HTTPException(status_code=409, detail="Director email already exists")

    director = Director(
        school_id=school_id,
        full_name=full_name,
        email=email.lower(),
        hashed_password=hash_password(password),
        is_active=True,
    )
    db.add(director)
    db.commit()
    db.refresh(director)
    return director


def authenticate_director(db: Session, email: str, password: str) -> Director:
    director = db.query(Director).filter(Director.email == email.lower()).first()
    if not director or not verify_password(password, director.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    if not director.is_active:
        raise HTTPException(status_code=403, detail="Director account is inactive")
    return director


def create_director_token(director: Director) -> str:
    return create_jwt_access_token(
        subject=str(director.id),
        claims={
            "role": "director",
            "email": director.email,
            "school_id": director.school_id,
        },
    )


def ensure_default_director(db: Session, default_school_id: int | None = None) -> Director:
    director = db.query(Director).filter(
        Director.email == DEFAULT_DIRECTOR_EMAIL
    ).first()
    if not director:
        director = Director(
            school_id=default_school_id,
            full_name="SmartSchool Director",
            email=DEFAULT_DIRECTOR_EMAIL,
            hashed_password=hash_password(DEFAULT_DIRECTOR_PASSWORD),
            is_active=True,
            is_superadmin=True,
        )
        db.add(director)
        db.commit()
        db.refresh(director)
    elif director.school_id is None and default_school_id is not None:
        director.school_id = default_school_id
        director.is_superadmin = True
        db.commit()
        db.refresh(director)

    if verify_password(DEFAULT_DIRECTOR_PASSWORD, director.hashed_password):
        print(
            "\n"
            "!!! SECURITY WARNING: the default director account "
            f"({DEFAULT_DIRECTOR_EMAIL}) still uses its default password. "
            "Log in and call POST /auth/director/change-password before "
            "using this instance for real students. !!!\n"
        )

    return director


def change_director_password(db: Session, director: Director, current_password: str, new_password: str) -> None:
    if not verify_password(current_password, director.hashed_password):
        raise HTTPException(status_code=401, detail="Current password is incorrect")
    director.hashed_password = hash_password(new_password)
    db.commit()
