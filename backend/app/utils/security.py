import hashlib
import secrets
from datetime import datetime, timedelta
from typing import Any

import jwt
from fastapi import HTTPException, status
from passlib.context import CryptContext

from app.utils.config import settings

password_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return password_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return password_context.verify(plain_password, hashed_password)


# Students verify against Public Server (no LAN access required, same as
# parents), which deliberately has no passlib/bcrypt dependency -- see
# public_server/app/utils/security.py::hash_school_key for the existing
# precedent of a dependency-light hash used there instead of bcrypt. This
# pair is computed once here (when a director sets/changes a student's
# password) and the resulting salt+hash are synced down; the plaintext is
# never stored or sent anywhere past this function.
def hash_student_password(password: str) -> tuple[str, str]:
    salt = secrets.token_hex(16)
    digest = hashlib.sha256((salt + password).encode("utf-8")).hexdigest()
    return salt, digest


def verify_student_password(password: str, salt: str, expected_hash: str) -> bool:
    digest = hashlib.sha256((salt + password).encode("utf-8")).hexdigest()
    return secrets.compare_digest(digest, expected_hash)


def create_jwt_access_token(subject: str, claims: dict[str, Any] | None = None) -> str:
    expire_at = datetime.utcnow() + timedelta(
        minutes=settings.jwt_access_token_minutes
    )
    payload = {
        "sub": subject,
        "exp": expire_at,
        "iat": datetime.utcnow(),
        **(claims or {}),
    }
    return jwt.encode(
        payload,
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )


def decode_jwt_access_token(token: str) -> dict[str, Any]:
    try:
        return jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm],
        )
    except jwt.PyJWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        ) from exc
