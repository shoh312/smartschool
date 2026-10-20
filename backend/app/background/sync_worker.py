import asyncio
from datetime import datetime, timedelta

import httpx

from app.database import SessionLocal
from app.models.sync_outbox_model import SyncOutboxEntry
from app.utils.config import settings

BATCH_SIZE = 100
CONCURRENCY = 10
POLL_INTERVAL_SECONDS = 2
MAX_BACKOFF_SECONDS = 300

# Small, user-facing changes (a new pupil login, an announcement, a test) go
# ahead of bulk history (grades, attendance, analytics), so a large backlog
# never holds them up for days. Within each group, oldest first.
URGENT_TYPES = ("student", "announcement", "calendar_event", "material", "material_assignment")


def _next_backoff(attempts: int) -> datetime:
    delay = min((2 ** attempts) * 5, MAX_BACKOFF_SECONDS)
    return datetime.utcnow() + timedelta(seconds=delay)


async def drain_outbox_once(db) -> None:
    now = datetime.utcnow()

    def _pending():
        # Two plain queries (both served by the indexes) rather than one sort
        # over the whole backlog: urgent types first, then the rest.
        base = db.query(SyncOutboxEntry).filter(
            SyncOutboxEntry.status == "pending", SyncOutboxEntry.next_attempt_at <= now
        )
        urgent = (
            base.filter(SyncOutboxEntry.entity_type.in_(URGENT_TYPES))
            .order_by(SyncOutboxEntry.id.asc()).limit(BATCH_SIZE).all()
        )
        room = BATCH_SIZE - len(urgent)
        if room <= 0:
            return urgent
        rest = (
            base.filter(SyncOutboxEntry.entity_type.notin_(URGENT_TYPES))
            .order_by(SyncOutboxEntry.id.asc()).limit(room).all()
        )
        return urgent + rest

    pending = await asyncio.to_thread(_pending)
    if not pending:
        return

    # Only the oldest event per entity goes out in a batch: two updates to the
    # same row must arrive in order, so the later one waits for the next batch.
    seen_entities: set[tuple[str, int]] = set()
    batch = []
    for entry in pending:
        key = (entry.entity_type, entry.entity_id)
        if key in seen_entities:
            continue
        seen_entities.add(key)
        batch.append(entry)

    gate = asyncio.Semaphore(CONCURRENCY)

    async def _send(client: httpx.AsyncClient, entry):
        async with gate:
            try:
                response = await client.post(
                    f"{settings.public_server_url}/sync/events",
                    json=entry.payload,
                    headers={"X-School-Key": settings.public_server_api_key},
                )
                if 200 <= response.status_code < 300:
                    return entry, None
                return entry, f"HTTP {response.status_code}: {response.text[:300]}"
            except httpx.HTTPError as exc:
                return entry, (str(exc) or type(exc).__name__)[:300]

    async with httpx.AsyncClient(timeout=10.0) as client:
        results = await asyncio.gather(*(_send(client, e) for e in batch))

    for entry, error in results:
        if error is None:
            entry.status = "sent"
            entry.last_error = None
        else:
            entry.attempts += 1
            entry.last_error = error
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
