"""At-rest encryption for the two things that identify a child's face: the
photo on disk and the embedding in the database.

AES-128-CBC + HMAC-SHA256 through Fernet (the `cryptography` package). The
key comes from FACE_DATA_KEY in .env; when that is not set it is derived
from SMARTSCHOOL_AUTH_SECRET, so an existing install keeps working without a
new setting. Whoever copies the uploads folder or dumps the students table
gets ciphertext -- the key lives only in the school server's environment.

Old rows written before this module existed are plain text and still read
fine: `decrypt_text` passes anything without the "enc:" prefix through, and
`read_photo` falls back to the raw bytes when they do not decrypt.
"""

import base64
import hashlib
import os

from cryptography.fernet import Fernet, InvalidToken

from app.utils.config import settings

PREFIX = "enc:"


def _fernet() -> Fernet:
    raw = os.getenv("FACE_DATA_KEY") or settings.auth_secret
    key = base64.urlsafe_b64encode(hashlib.sha256(raw.encode("utf-8")).digest())
    return Fernet(key)


def encrypt_text(plain: str) -> str:
    return PREFIX + _fernet().encrypt(plain.encode("utf-8")).decode("ascii")


def decrypt_text(value: str | None) -> str | None:
    if value is None or not value.startswith(PREFIX):
        return value
    return _fernet().decrypt(value[len(PREFIX):].encode("ascii")).decode("utf-8")


def is_encrypted(value: str | None) -> bool:
    return bool(value) and value.startswith(PREFIX)


def encrypt_file_in_place(path: str) -> None:
    with open(path, "rb") as fh:
        data = fh.read()
    with open(path, "wb") as fh:
        fh.write(_fernet().encrypt(data))


def read_photo(path: str) -> bytes:
    with open(path, "rb") as fh:
        data = fh.read()
    try:
        return _fernet().decrypt(data)
    except InvalidToken:
        return data
