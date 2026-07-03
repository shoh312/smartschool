from app.database import SessionLocal
from app.models.notification_model import NotificationEvent
from app.models.student import Student
from app.models.parent_model import Parent
from app.models.class_model import Class
from app.models.camera_model import Camera
from app.models.attendance_model import Attendance
from app.notifications.firebase import send_pending_notifications

def run_sending():
    db = SessionLocal()
    try:
        pending = db.query(NotificationEvent).filter(NotificationEvent.status == "pending").all()
        print(f"Direct query found {len(pending)} pending events.")
        
        print("Running send_pending_notifications...")
        sent_events = send_pending_notifications(db)
        print(f"Processed {len(sent_events)} events.")
        for e in sent_events:
            print(f"  Event: {e.title}, Status: {e.status}, Error: {e.error}")
    finally:
        db.close()

if __name__ == "__main__":
    run_sending()
