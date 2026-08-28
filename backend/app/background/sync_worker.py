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

    # Threaded: this runs every two seconds, and a synchronous query on the
    # event loop is a stall the whole server shares -- most visibly the live
    # video, which is being pushed frame by frame from that same loop.
    pending = await asyncio.to_thread(_pending)
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
    import app.realtime as realtime

    while True:
        # Clear BEFORE draining, not after: a wake-up that arrives while
        # drain_outbox_once is still running must survive to the wait()
        # below (where it resolves instantly) instead of being wiped by a
        # clear() that runs right after drain finishes -- that ordering
        # silently swallowed the signal and fell all the way back to the
        # POLL_INTERVAL_SECONDS timeout every time, defeating the point of
        # having a wake-up at all.
        event = realtime.sync_wake_event
        if event is not None:
            event.clear()

        db = SessionLocal()
        try:
            await drain_outbox_once(db)
        finally:
            db.close()

        # Wait for either the next poll tick (catches retries whose backoff
        # has elapsed) or an immediate wake-up signaled by enqueue_*_event
        # right when something new is queued -- whichever comes first, so a
        # fresh grade/attendance/enrollment syncs in well under a second
        # instead of waiting up to POLL_INTERVAL_SECONDS.
        if event is not None:
            try:
                await asyncio.wait_for(event.wait(), timeout=POLL_INTERVAL_SECONDS)
            except asyncio.TimeoutError:
                pass
        else:
            await asyncio.sleep(POLL_INTERVAL_SECONDS)
