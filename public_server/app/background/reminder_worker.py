"""Hourly pass that nudges pupils about work due tomorrow.

This is the Public Server's only background loop -- everything else here is
request-driven. It lives here rather than on the school server for the same
reason the pupil-facing API does: this is the side that can actually reach a
pupil's phone, and the side that knows who has already submitted.
"""

import asyncio

from app.database import SessionLocal
from app.services.material_notification_service import send_due_reminders

# Hourly is the right granularity for a one-day-ahead reminder: often
# enough that nobody gets theirs a long way late, rare enough that the pass
# costs nothing. Each reminder is sent once per pupil per assignment (see
# _already_sent), so a repeat pass is harmless.
INTERVAL_SECONDS = 3600


async def reminder_loop():
    while True:
        try:
            db = SessionLocal()
            try:
                send_due_reminders(db)
            finally:
                db.close()
        except Exception as exc:  # noqa: BLE001 -- one bad row must not stop the loop
            print(f"[reminders] {exc}")
        await asyncio.sleep(INTERVAL_SECONDS)
