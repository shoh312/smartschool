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
    pending = (
        db.query(SyncOutboxEntry)
        .filter(SyncOutboxEntry.status == "pending", SyncOutboxEntry.next_attempt_at <= now)
        .order_by(SyncOutboxEntry.id.asc())
        .limit(BATCH_SIZE)
        .all()
    )
    if not pending:
        return

    # Ordering guard: within this batch, don't let a later event for the same
    # entity race ahead of an earlier one that's still unresolved (e.g. an
    # "update grade" retry overtaking its own preceding "create grade"
    # attempt) -- different entities stay fully independent so one stuck row
    # never blocks the rest.
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
                # Network blip, Public Server down, DNS failure, etc. -- retry
                # forever with backoff, never a terminal give-up state (this
                # is the exact failure mode fixed for the RTSP camera thread
                # earlier this session: a single failure must not silently
                # and permanently stop the retry loop).
                entry.attempts += 1
                entry.last_error = str(exc)[:300]
                entry.next_attempt_at = _next_backoff(entry.attempts)

            db.commit()


async def sync_background_loop():
    while True:
        db = SessionLocal()
        try:
            await drain_outbox_once(db)
        finally:
            db.close()
        await asyncio.sleep(POLL_INTERVAL_SECONDS)
