from datetime import datetime

from sqlalchemy.orm import Session

from app.models.notification_model import DeviceToken, NotificationEvent
from app.utils.config import settings

try:
    import firebase_admin
    from firebase_admin import credentials, messaging
except ImportError:
    firebase_admin = None
    credentials = None
    messaging = None


def initialize_firebase():
    if firebase_admin is None or firebase_admin._apps:
        return

    if settings.firebase_credentials:
        cred = credentials.Certificate(settings.firebase_credentials)
        firebase_admin.initialize_app(cred)
    else:
        firebase_admin.initialize_app()


def create_and_send_notification(db: Session, event: NotificationEvent) -> NotificationEvent:
    from app.utils.config import settings as _settings
    if not _settings.notifications_enabled:
        event.status = "skipped"
        event.error = "Notifications are switched off (NOTIFICATIONS_ENABLED=false)"
        db.commit()
        return event

    if event.parent_id:
        owner = DeviceToken.parent_id == event.parent_id
    elif event.student_id:
        owner = DeviceToken.student_id == event.student_id
    else:
        event.status = "skipped"
        event.error = "No recipient assigned"
        db.commit()
        return event

    tokens = db.query(DeviceToken).filter(
        owner,
        DeviceToken.is_active == True,
    ).all()

    if not tokens:
        event.status = "skipped"
        event.error = "No active device token"
        db.commit()
        return event

    if firebase_admin is None:
        event.status = "pending"
        event.error = "firebase-admin is not installed"
        db.commit()
        return event

    try:
        initialize_firebase()
        message = messaging.MulticastMessage(
            notification=messaging.Notification(title=event.title, body=event.body),
            tokens=[token.token for token in tokens],
            data={
                "event_type": event.event_type,
                "student_id": str(event.student_id or ""),
            },
        )
        response = messaging.send_each_for_multicast(message)
        event.status = "sent" if response.success_count else "failed"
        event.error = (
            None
            if response.success_count
            else f"Firebase delivery failed (success: {response.success_count}, failure: {response.failure_count})"
        )
        event.sent_at = datetime.now()
    except Exception as exc:
        event.status = "failed"
        event.error = str(exc)

    db.commit()
    db.refresh(event)
    return event
