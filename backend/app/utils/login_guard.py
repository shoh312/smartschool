"""Brute-force guard for password logins.

After MAX_FAILURES wrong passwords for one login inside WINDOW_SECONDS, that
login is refused (429) until the oldest failure ages out. Counted per login,
not per IP: behind the relay every request arrives from the same address.
In memory -- a restart clears it, which is fine for a lockout this short.
"""
import threading
import time

from fastapi import HTTPException

MAX_FAILURES = 10
WINDOW_SECONDS = 15 * 60

_failures: dict[str, list[float]] = {}
_lock = threading.Lock()


def _recent(key: str, now: float) -> list[float]:
    stamps = [t for t in _failures.get(key, []) if now - t < WINDOW_SECONDS]
    if stamps:
        _failures[key] = stamps
    else:
        _failures.pop(key, None)
    return stamps


def check_login_allowed(key: str) -> None:
    with _lock:
        if len(_recent(key, time.time())) >= MAX_FAILURES:
            raise HTTPException(status_code=429, detail="too_many_attempts")


def record_login_failure(key: str) -> None:
    now = time.time()
    with _lock:
        _recent(key, now)
        _failures.setdefault(key, []).append(now)


def clear_login_failures(key: str) -> None:
    with _lock:
        _failures.pop(key, None)
