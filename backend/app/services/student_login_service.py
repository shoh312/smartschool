"""Issuing pupils their own logins, in bulk.

A pupil's half of the app -- their assignments, their marks, their rating --
is unreachable without one, and typing 79 usernames and passwords by hand
is why 78 of them didn't have one. So the director asks once per class and
gets a list back.

The passwords are returned in plain text exactly once, in the response to
the request that created them. They are stored only as a salted hash, so
this is the single moment they can be written down or handed out; asking
again issues new ones rather than revealing the old.
"""

import re
import secrets

from sqlalchemy.orm import Session

from app.models.student import Student
from app.utils.security import hash_student_password

# Ambiguous characters left out on purpose: these get copied off a screen
# onto paper and typed back in by a child, and 0/O and 1/l/I are where that
# goes wrong.
_PASSWORD_ALPHABET = "abcdefghijkmnpqrstuvwxyz23456789"
PASSWORD_LENGTH = 8

# Tajik/Russian Cyrillic to Latin, so a username can be typed on any
# keyboard the school happens to have.
_TRANSLITERATE = {
    "а": "a", "б": "b", "в": "v", "г": "g", "ғ": "gh", "д": "d", "е": "e",
    "ё": "yo", "ж": "j", "з": "z", "и": "i", "ӣ": "i", "й": "y", "к": "k",
    "қ": "q", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p", "р": "r",
    "с": "s", "т": "t", "у": "u", "ӯ": "u", "ф": "f", "х": "x", "ҳ": "h",
    "ц": "ts", "ч": "ch", "ҷ": "j", "ш": "sh", "щ": "sh", "ъ": "", "ы": "i",
    "ь": "", "э": "e", "ю": "yu", "я": "ya",
}


def _slug(value: str) -> str:
    text = (value or "").strip().lower()
    text = "".join(_TRANSLITERATE.get(char, char) for char in text)
    text = re.sub(r"[^a-z0-9]+", "", text)
    return text


def generate_password() -> str:
    return "".join(secrets.choice(_PASSWORD_ALPHABET) for _ in range(PASSWORD_LENGTH))


def _unique_username(db: Session, first_name: str, last_name: str, taken: set[str]) -> str:
    base = f"{_slug(first_name)}.{_slug(last_name)}".strip(".")
    if not base or base == ".":
        base = "student"
    base = base[:24]

    candidate = base
    suffix = 1
    while candidate in taken or db.query(Student).filter(Student.username == candidate).first():
        suffix += 1
        candidate = f"{base}{suffix}"
    taken.add(candidate)
    return candidate


def issue_login_for(
    db: Session,
    student: Student,
    password: str | None = None,
) -> tuple[str, str]:
    """One pupil, at the moment they are registered. Returns (username,
    plaintext password).

    Separate from `issue_logins` because that one deliberately skips a pupil
    who already has a username -- correct when re-running it for a whole
    class, wrong here, where the director may have typed a username but left
    the password blank and would otherwise end up with an account nobody can
    sign into.
    """
    if not student.username:
        student.username = _unique_username(db, student.first_name, student.last_name, set())

    plaintext = password or generate_password()
    student.password_salt, student.password_hash = hash_student_password(plaintext)
    return student.username, plaintext


def issue_logins(
    db: Session,
    students: list[Student],
    *,
    reset_existing: bool = False,
) -> list[dict]:
    """Give each pupil a username and password.

    Pupils who already have a login are skipped unless `reset_existing` --
    re-running this for a class must not silently invalidate the logins
    children have already learned.

    Returns one row per pupil actually issued, carrying the plain password.
    Nothing else in the system ever sees it again.
    """
    taken: set[str] = set()
    issued: list[dict] = []

    for student in students:
        if student.username and not reset_existing:
            continue

        username = student.username if (student.username and reset_existing) else _unique_username(
            db, student.first_name, student.last_name, taken
        )
        password = generate_password()
        salt, digest = hash_student_password(password)

        student.username = username
        student.password_salt = salt
        student.password_hash = digest

        issued.append(
            {
                "student_id": student.id,
                "full_name": f"{student.last_name} {student.first_name}".strip(),
                "username": username,
                "password": password,
            }
        )

    return issued
