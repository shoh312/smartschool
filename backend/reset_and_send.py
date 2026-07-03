from app.database import SessionLocal
from app.models.student import Student
from app.models.parent_model import Parent
from app.models.class_model import Class
from app.models.camera_model import Camera
from app.models.attendance_model import Attendance
from app.models.notification_model import DeviceToken, NotificationEvent
from app.notifications.firebase import send_pending_notifications

def reset_and_send():
    db = SessionLocal()
    try:
        # 1. Reset failed events for parent 6
        events = db.query(NotificationEvent).filter(
            NotificationEvent.parent_id == 6,
            NotificationEvent.status == "failed"
        ).all()
        
        print(f"Resetting {len(events)} failed events to pending...")
        for e in events:
            e.status = "pending"
            e.error = None
        db.commit()
        
        # 2. Run sending
        print("Running send_pending_notifications...")
        sent_events = send_pending_notifications(db)
        print(f"Processed {len(sent_events)} events.")
        for e in sent_events:
            print(f"  Event ID: {e.id}, Status: {e.status}, Error: {e.error}")
            
    finally:
        db.close()

if __name__ == "__main__":
    reset_and_send()
