from datetime import datetime

from sqlalchemy.orm import Session

from app.models.notification_model import DeviceToken, NotificationEvent
from app.models.parent_model import Parent
from app.services.auth_service import get_parent_family_ids
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


def create_notification_event(
    db: Session,
    event_type: str,
    title: str,
    body: str,
    parent_id: int | None = None,
    student_id: int | None = None,
    attendance_id: int | None = None,
) -> NotificationEvent:
    event = NotificationEvent(
        parent_id=parent_id,
        student_id=student_id,
        attendance_id=attendance_id,
        event_type=event_type,
        title=title,
        body=body,
    )
    db.add(event)
    db.commit()
    db.refresh(event)
    return event


def send_notification_event(db: Session, event: NotificationEvent) -> NotificationEvent:
    if not event.parent_id:
        event.status = "skipped"
        event.error = "No parent assigned"
        db.commit()
        return event

    # A device's Firebase token is registered against whichever Parent row
    # was active at login time, but a parent with children at two schools
    # has a sibling Parent row (same phone, different school) that this
    # event might belong to instead -- look up tokens across the whole
    # family so a school-B attendance event still reaches a device that
    # only ever logged in and registered its token under school-A's row.
    # DeviceToken.token is unique, so a token can't just be duplicated onto
    # every sibling row at registration time.
    parent = db.query(Parent).filter(Parent.id == event.parent_id).first()
    family_ids = get_parent_family_ids(db, parent) if parent else [event.parent_id]

    tokens = db.query(DeviceToken).filter(
        DeviceToken.parent_id.in_(family_ids),
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
                "attendance_id": str(event.attendance_id or ""),
            },
        )
        response = messaging.send_each_for_multicast(message)
        event.status = "sent" if response.success_count else "failed"
        event.error = None if response.success_count else f"Firebase delivery failed (success: {response.success_count}, failure: {response.failure_count})"
        event.sent_at = datetime.now()
    except Exception as exc:
        event.status = "failed"
        event.error = str(exc)

    db.commit()
    db.refresh(event)
    return event


def send_pending_notifications(db: Session, limit: int = 50) -> list[NotificationEvent]:
    events = db.query(NotificationEvent).filter(
        NotificationEvent.status == "pending",
    ).order_by(NotificationEvent.id.asc()).limit(limit).all()

    return [send_notification_event(db, event) for event in events]
