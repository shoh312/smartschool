from app.database import SessionLocal
from app.models.student import Student
from app.models.parent_model import Parent
from app.models.class_model import Class
from app.models.camera_model import Camera
from app.models.attendance_model import Attendance
from app.models.notification_model import DeviceToken, NotificationEvent

def debug_parent_6():
    db = SessionLocal()
    try:
        events = db.query(NotificationEvent).filter(NotificationEvent.parent_id == 6).all()
        print(f"Found {len(events)} events for parent 6")
        for e in events:
            print(f"  Current Status: {e.status}")
            e.status = "pending"
            e.error = None
        
        db.commit()
        print("Committed changes.")
        
        # Verify
        db.expire_all()
        events = db.query(NotificationEvent).filter(NotificationEvent.parent_id == 6).all()
        for e in events:
            print(f"  New Status (after verify): {e.status}")
            
    finally:
        db.close()

if __name__ == "__main__":
    debug_parent_6()
