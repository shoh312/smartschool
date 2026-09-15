import asyncio

_main_loop: asyncio.AbstractEventLoop | None = None
sync_wake_event: asyncio.Event | None = None


def set_main_loop(loop: asyncio.AbstractEventLoop) -> None:
    global _main_loop, sync_wake_event
    _main_loop = loop
    sync_wake_event = asyncio.Event()


def broadcast_attendance_update() -> None:
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
    if _main_loop is None or sync_wake_event is None:
        return
    _main_loop.call_soon_threadsafe(sync_wake_event.set)
