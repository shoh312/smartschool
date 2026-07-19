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


def hash_school_key(raw_key: str) -> str:
    return hashlib.sha256(raw_key.encode("utf-8")).hexdigest()


def verify_school_key(raw_key: str, key_hash: str) -> bool:
    return hmac.compare_digest(hash_school_key(raw_key), key_hash)
