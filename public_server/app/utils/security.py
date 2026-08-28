import base64
import hashlib
import hmac
import json
from datetime import datetime, timedelta

from fastapi import HTTPException, status

from app.utils.config import settings


def _sign(payload: str) -> str:
    return hmac.new(
        settings.auth_secret.encode("utf-8"),
        payload.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def create_parent_access_token(parent_id: int) -> str:
    payload = {
        "parent_id": parent_id,
        "exp": (datetime.utcnow() + timedelta(days=30)).isoformat(),
    }
    payload_text = json.dumps(payload, separators=(",", ":"))
    encoded = base64.urlsafe_b64encode(payload_text.encode("utf-8")).decode("utf-8")
    return f"{encoded}.{_sign(encoded)}"


def verify_parent_access_token(token: str) -> int:
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


def create_setup_token(parent_id: int, ttl: timedelta) -> str:
    """Proof that this phone answered its SMS, and nothing more.

    Deliberately a different payload key from the access token: a token
    minted for choosing a password must not open the child's marks, and a
    30-day access token must not be usable to overwrite the password. Each
    verifier reads only its own key, so neither is accepted in the other's
    place.
    """
    payload = {
        "setup_parent_id": parent_id,
        "exp": (datetime.utcnow() + ttl).isoformat(),
    }
    payload_text = json.dumps(payload, separators=(",", ":"))
    encoded = base64.urlsafe_b64encode(payload_text.encode("utf-8")).decode("utf-8")
    return f"{encoded}.{_sign(encoded)}"


def verify_setup_token(token: str) -> int:
    try:
        encoded, signature = token.split(".", 1)
        if not hmac.compare_digest(signature, _sign(encoded)):
            raise ValueError
        payload = json.loads(base64.urlsafe_b64decode(encoded.encode("utf-8")))
        if datetime.fromisoformat(payload["exp"]) < datetime.utcnow():
            raise ValueError
        return int(payload["setup_parent_id"])
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="setup_token_invalid",
        ) from exc


def create_student_access_token(student_id: int) -> str:
    payload = {
        "student_id": student_id,
        "exp": (datetime.utcnow() + timedelta(days=30)).isoformat(),
    }
    payload_text = json.dumps(payload, separators=(",", ":"))
    encoded = base64.urlsafe_b64encode(payload_text.encode("utf-8")).decode("utf-8")
    return f"{encoded}.{_sign(encoded)}"


def verify_student_access_token(token: str) -> int:
    try:
        encoded, signature = token.split(".", 1)
        if not hmac.compare_digest(signature, _sign(encoded)):
            raise ValueError
        payload = json.loads(base64.urlsafe_b64decode(encoded.encode("utf-8")))
        if datetime.fromisoformat(payload["exp"]) < datetime.utcnow():
            raise ValueError
        return int(payload["student_id"])
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        ) from exc


# Same dependency-light salted-sha256 scheme as the local server's
# hash_student_password (see backend/app/utils/security.py) -- this server
# only ever verifies against the synced hash, it never hashes a plaintext
# password itself (that only happens locally, when a director sets one).
def verify_student_password(password: str, salt: str, expected_hash: str) -> bool:
    digest = hashlib.sha256((salt + password).encode("utf-8")).hexdigest()
    return hmac.compare_digest(digest, expected_hash)


def hash_school_key(raw_key: str) -> str:
    return hashlib.sha256(raw_key.encode("utf-8")).hexdigest()


def verify_school_key(raw_key: str, key_hash: str) -> bool:
    return hmac.compare_digest(hash_school_key(raw_key), key_hash)
