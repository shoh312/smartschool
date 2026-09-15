
import asyncio
from datetime import datetime

import httpx

from app.database import SessionLocal
from app.models.material_model import MaterialAssignment, MaterialAttempt
from app.models.student import Student
from app.utils.config import settings

POLL_INTERVAL_SECONDS = 30
BATCH_SIZE = 200
REQUEST_TIMEOUT_SECONDS = 20.0


def _parse_dt(value):
    if not value:
        return None
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00")).replace(tzinfo=None)
    except ValueError:
        return None


def _apply_attempt(db, row: dict) -> bool:
    assignment = (
        db.query(MaterialAssignment)
        .filter(MaterialAssignment.id == row.get("local_assignment_id"))
        .first()
    )
    student = db.query(Student).filter(Student.id == row.get("local_student_id")).first()
    if assignment is None or student is None:
        return False

    attempt = (
        db.query(MaterialAttempt)
        .filter(MaterialAttempt.public_id == row["public_id"])
        .first()
    )
    if attempt is None:
        attempt = MaterialAttempt(public_id=row["public_id"])
        db.add(attempt)

    attempt.assignment_id = assignment.id
    attempt.student_id = student.id
    attempt.attempt_no = row.get("attempt_no") or 1
    attempt.started_at = _parse_dt(row.get("started_at"))
    attempt.submitted_at = _parse_dt(row.get("submitted_at"))
    attempt.score = row.get("score")
    attempt.max_score = row.get("max_score")
    attempt.answers = row.get("answers")
    return True


async def pull_attempts_once() -> int:
    if not settings.public_server_api_key:
        return 0

    headers = {"X-School-Key": settings.public_server_api_key}
    async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT_SECONDS) as client:
        response = await client.get(
            f"{settings.public_server_url}/sync/attempts",
            params={"limit": BATCH_SIZE},
            headers=headers,
        )
        response.raise_for_status()
        rows = response.json() or []
        if not rows:
            return 0

        db = SessionLocal()
        try:
            acked: list[int] = []
            for row in rows:
                if _apply_attempt(db, row):
                    acked.append(row["public_id"])
            db.commit()
        finally:
            db.close()

        if acked:
            await client.post(
                f"{settings.public_server_url}/sync/attempts/ack",
                json={"public_ids": acked},
                headers=headers,
            )
        return len(acked)


async def attempt_pull_loop():
    while True:
        try:
            await pull_attempts_once()
        except (httpx.HTTPError, OSError):
            pass
        except Exception as exc:
            print(f"[attempt-pull] unexpected error: {ascii(str(exc))}")
        await asyncio.sleep(POLL_INTERVAL_SECONDS)
