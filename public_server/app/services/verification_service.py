# -*- coding: utf-8 -*-
"""The rules around SMS codes, kept apart from the endpoints that apply them.

Every rule here exists because the alternative costs the school money or an
account:

  * a code that never expires is a permanent key sitting in someone's inbox;
  * a code that can be guessed without limit is six digits of nothing;
  * an endpoint that sends an SMS on every request is a way for a stranger
    to spend the school's balance, one message at a time.

The functions are pure so the policy can be tested without a database, a
gateway, or a clock.
"""

import hashlib
import hmac
import secrets
from dataclasses import dataclass
from datetime import datetime, timedelta

CODE_LENGTH = 6
CODE_TTL = timedelta(minutes=5)

# A wrong guess is cheap for the attacker and expensive for nobody, so the
# ceiling has to be low: five tries against a six-digit code is a 1-in-200000
# chance, and the sixth try forces them to request a new SMS -- which the
# hourly limit below then blocks.
MAX_ATTEMPTS = 5

# Per phone, per hour. Three covers a parent who mistypes their number,
# waits for a slow message, and tries once more; it does not cover a script.
MAX_CODES_PER_HOUR = 3
RATE_WINDOW = timedelta(hours=1)

# Long enough to type a name and choose a password, short enough that a
# token left in a log is worthless by the time anyone reads it.
SETUP_TOKEN_TTL = timedelta(minutes=15)


def generate_code() -> str:
    """A six-digit code, zero-padded, from the system's secure source.

    `random` would be predictable from a handful of observed codes; this is
    a credential, so it comes from `secrets`.
    """
    return str(secrets.randbelow(10**CODE_LENGTH)).zfill(CODE_LENGTH)


def hash_secret(secret: str, salt: str) -> str:
    return hashlib.sha256((salt + secret).encode("utf-8")).hexdigest()


def new_salt() -> str:
    return secrets.token_hex(16)


def hash_password(password: str) -> tuple[str, str]:
    """Returns (salt, hash). Same salted-sha256 scheme the students already
    use -- see backend/app/utils/security.py for why this server carries no
    passlib dependency.
    """
    salt = new_salt()
    return salt, hash_secret(password, salt)


def verify_password(password: str, salt: str | None, expected_hash: str | None) -> bool:
    if not salt or not expected_hash:
        return False
    return hmac.compare_digest(hash_secret(password, salt), expected_hash)


@dataclass(frozen=True)
class CodeCheck:
    """Whether a submitted code may be accepted, and why not if it may not.

    `reason` is what the phone shows the parent, so the three cases are kept
    apart: an expired code needs a new one, a wrong code needs another try,
    and a burnt-out code needs both.
    """

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
        # Already spent. Reusing one would let anyone who saw the SMS come
        # back to it later, after the parent had finished with it.
        return CodeCheck(False, "code_already_used")
    if attempts >= MAX_ATTEMPTS:
        return CodeCheck(False, "too_many_attempts")
    if now > expires_at:
        return CodeCheck(False, "code_expired")
    if not hmac.compare_digest(hash_secret(submitted, code_salt), code_hash):
        return CodeCheck(False, "code_invalid")
    return CodeCheck(True)


def may_send_code(recent_sends: int) -> bool:
    """`recent_sends` is how many codes this phone was sent inside
    RATE_WINDOW. Counted per phone rather than per IP: the phone number is
    what costs money to reach, and a school shares one network anyway.
    """
    return recent_sends < MAX_CODES_PER_HOUR


def expiry_from(now: datetime) -> datetime:
    return now + CODE_TTL


def mask_phone(phone: str) -> str:
    """`992987644002` -> `+992 ** *** 40 02`.

    Echoed back so the parent can see which number the message went to
    without the response confirming a full number to whoever asked for it.
    """
    digits = "".join(character for character in phone if character.isdigit())
    if len(digits) < 4:
        return "***"
    return "+%s ** *** %s %s" % (digits[:3], digits[-4:-2], digits[-2:])
