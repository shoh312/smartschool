import asyncio
from datetime import datetime, timedelta

import httpx

from app.database import SessionLocal
from app.models.sync_outbox_model import SyncOutboxEntry
from app.utils.config import settings

BATCH_SIZE = 50
POLL_INTERVAL_SECONDS = 2
MAX_BACKOFF_SECONDS = 300


def _next_backoff(attempts: int) -> datetime:
    delay = min((2 ** attempts) * 5, MAX_BACKOFF_SECONDS)
    return datetime.utcnow() + timedelta(seconds=delay)


async def drain_outbox_once(db) -> None:
    now = datetime.utcnow()

    def _pending():
        return (
            db.query(SyncOutboxEntry)
            .filter(SyncOutboxEntry.status == "pending", SyncOutboxEntry.next_attempt_at <= now)
            .order_by(SyncOutboxEntry.id.asc())
            .limit(BATCH_SIZE)
            .all()
        )

    pending = await asyncio.to_thread(_pending)
    if not pending:
        return

    seen_entities: set[tuple[str, int]] = set()

    async with httpx.AsyncClient(timeout=10.0) as client:
        for entry in pending:
            key = (entry.entity_type, entry.entity_id)
            if key in seen_entities:
                continue
            seen_entities.add(key)

            try:
                response = await client.post(
                    f"{settings.public_server_url}/sync/events",
                    json=entry.payload,
                    headers={"X-School-Key": settings.public_server_api_key},
                )
                if 200 <= response.status_code < 300:
                    entry.status = "sent"
                    entry.last_error = None
                else:
                    entry.attempts += 1
                    entry.last_error = f"HTTP {response.status_code}: {response.text[:300]}"
                    entry.next_attempt_at = _next_backoff(entry.attempts)
            except httpx.HTTPError as exc:
                entry.attempts += 1
                entry.last_error = str(exc)[:300]
                entry.next_attempt_at = _next_backoff(entry.attempts)

            db.commit()


async def sync_background_loop():
    import app.realtime as realtime

    while True:
        event = realtime.sync_wake_event
        if event is not None:
            event.clear()

        db = SessionLocal()
        try:
            await drain_outbox_once(db)
        finally:
            db.close()

        if event is not None:
            try:
                await asyncio.wait_for(event.wait(), timeout=POLL_INTERVAL_SECONDS)
            except asyncio.TimeoutError:
                pass
        else:
            await asyncio.sleep(POLL_INTERVAL_SECONDS)
