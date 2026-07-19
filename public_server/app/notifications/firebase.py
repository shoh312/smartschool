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
    """Send immediately (the Public Server is the sole owner of parent push
    notifications now -- unlike the local server's version of this function,
    there's no cross-school Parent-row family to fan out across, since a
    Public Server parent is one global row per phone).
    """
    if not event.parent_id:
        event.status = "skipped"
        event.error = "No parent assigned"
        db.commit()
        return event

    tokens = db.query(DeviceToken).filter(
        DeviceToken.parent_id == event.parent_id,
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
