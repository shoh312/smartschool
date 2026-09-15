
import asyncio

from app.database import SessionLocal
from app.services.material_notification_service import send_due_reminders

INTERVAL_SECONDS = 3600


async def reminder_loop():
    while True:
        try:
            db = SessionLocal()
            try:
                send_due_reminders(db)
            finally:
                db.close()
        except Exception as exc:
            print(f"[reminders] {exc}")
        await asyncio.sleep(INTERVAL_SECONDS)
