from app.database import SessionLocal
from app.models.notification_model import NotificationEvent
from app.models.student import Student
from app.models.parent_model import Parent
from app.models.class_model import Class
from app.models.camera_model import Camera
from app.models.attendance_model import Attendance

def check_event_15():
    db = SessionLocal()
    try:
        e = db.query(NotificationEvent).filter(NotificationEvent.id == 15).first()
        print(f"ID: {e.id}, Status: {e.status}, Error: {e.error}")
    finally:
        db.close()

if __name__ == "__main__":
    check_event_15()
