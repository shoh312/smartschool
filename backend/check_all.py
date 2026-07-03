from app.database import SessionLocal
from app.models.notification_model import NotificationEvent
from app.models.student import Student
from app.models.parent_model import Parent
from app.models.class_model import Class
from app.models.camera_model import Camera
from app.models.attendance_model import Attendance

def check_all_pending():
    db = SessionLocal()
    try:
        events = db.query(NotificationEvent).all()
        print(f"Total events in DB: {len(events)}")
        for e in events:
            print(f"ID: {e.id}, Parent ID: {e.parent_id}, Title: {e.title}, Status: {e.status}")
    finally:
        db.close()

if __name__ == "__main__":
    check_all_pending()
