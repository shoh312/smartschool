
import hashlib
import hmac
import secrets
from dataclasses import dataclass
from datetime import datetime, timedelta

CODE_LENGTH = 6
CODE_TTL = timedelta(minutes=5)

MAX_ATTEMPTS = 5

MAX_CODES_PER_HOUR = 3
RATE_WINDOW = timedelta(hours=1)

SETUP_TOKEN_TTL = timedelta(minutes=15)


def generate_code() -> str:
    return str(secrets.randbelow(10**CODE_LENGTH)).zfill(CODE_LENGTH)


def hash_secret(secret: str, salt: str) -> str:
    return hashlib.sha256((salt + secret).encode("utf-8")).hexdigest()


def new_salt() -> str:
    return secrets.token_hex(16)


def hash_password(password: str) -> tuple[str, str]:
    salt = new_salt()
    return salt, hash_secret(password, salt)


def verify_password(password: str, salt: str | None, expected_hash: str | None) -> bool:
    if not salt or not expected_hash:
        return False
    return hmac.compare_digest(hash_secret(password, salt), expected_hash)


@dataclass(frozen=True)
class CodeCheck:

    ok: bool
    reason: str = ""


def check_code(
    submitted: str,
    *,
    code_salt: str,
    code_hash: str,
    expires_at: datetime,
    attempts: int,
    consumed_at: datetime | None,
    now: datetime,
) -> CodeCheck:
    if consumed_at is not None:
        return CodeCheck(False, "code_already_used")
    if attempts >= MAX_ATTEMPTS:
        return CodeCheck(False, "too_many_attempts")
    if now > expires_at:
        return CodeCheck(False, "code_expired")
    if not hmac.compare_digest(hash_secret(submitted, code_salt), code_hash):
        return CodeCheck(False, "code_invalid")
    return CodeCheck(True)


def may_send_code(recent_sends: int) -> bool:
    return recent_sends < MAX_CODES_PER_HOUR


def expiry_from(now: datetime) -> datetime:
    return now + CODE_TTL


def mask_phone(phone: str) -> str:
    digits = "".join(character for character in phone if character.isdigit())
    if len(digits) < 4:
        return "***"
    return "+%s ** *** %s %s" % (digits[:3], digits[-4:-2], digits[-2:])
