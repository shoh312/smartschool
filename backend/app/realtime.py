"""Thread-safe bridge from synchronous worker threads (the camera detection
loop, and FastAPI's threadpool for `def` route handlers) onto the main
asyncio event loop.

Websocket broadcasts and the sync-outbox drain loop are asyncio-native and
live on the loop uvicorn runs; the camera detection code is a plain
threading.Thread (OpenCV/insightface calls block, so it can't be a coroutine)
and FastAPI's sync `def` endpoints run in a separate threadpool. Neither can
safely touch an asyncio.Event or call an async function directly -- they
have to hand the work to the loop via run_coroutine_threadsafe /
call_soon_threadsafe instead.
"""
import asyncio

_main_loop: asyncio.AbstractEventLoop | None = None
sync_wake_event: asyncio.Event | None = None


def set_main_loop(loop: asyncio.AbstractEventLoop) -> None:
    global _main_loop, sync_wake_event
    _main_loop = loop
    sync_wake_event = asyncio.Event()


def broadcast_attendance_update() -> None:
    """Push the current live-status snapshot to every connected director
    immediately, instead of waiting for the 30s periodic broadcast. Safe to
    call from any thread.
    """
    if _main_loop is None:
        return

    async def _send():
        from app.background.tasks import _live_status_payload
        from app.database import SessionLocal
        from app.websocket.manager import manager

        db = SessionLocal()
        try:
            await manager.broadcast(_live_status_payload(db))
        finally:
            db.close()

    asyncio.run_coroutine_threadsafe(_send(), _main_loop)


def wake_sync_worker() -> None:
    """Wake the sync-outbox drain loop immediately instead of waiting for
    its next poll tick. Safe to call from any thread.

    Must only be called AFTER the enqueuing transaction has actually
    committed -- calling it earlier races the drain loop against the
    caller's own db.commit() (call_soon_threadsafe's callback can run on the
    event loop before the originating thread gets scheduled back to finish
    its commit), so the loop wakes, finds nothing yet, and falls all the way
    back to the POLL_INTERVAL_SECONDS timeout anyway. See sync_outbox_service
    for where this is actually wired to fire (SQLAlchemy's after_commit
    session event, not the enqueue call site).
    """
    if _main_loop is None or sync_wake_event is None:
        return
    _main_loop.call_soon_threadsafe(sync_wake_event.set)
