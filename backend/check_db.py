from app.database import SessionLocal
# Import all models to satisfy SQLAlchemy relationships
from app.models.student import Student
from app.models.parent_model import Parent
from app.models.class_model import Class
from app.models.camera_model import Camera
from app.models.attendance_model import Attendance
from app.models.notification_model import DeviceToken, NotificationEvent

def check_tokens():
    db = SessionLocal()
    try:
        parents = db.query(Parent).all()
        print(f"Total parents: {len(parents)}")
        for p in parents:
            tokens = db.query(DeviceToken).filter(DeviceToken.parent_id == p.id).all()
            print(f"Parent: {p.full_name} ({p.phone}), ID: {p.id}")
            if not tokens:
                print("  [!] No device tokens found for this parent.")
            for t in tokens:
                print(f"  [-] Token: {t.token[:20]}... Platform: {t.platform}, Active: {t.is_active}")
            
            notifications = db.query(NotificationEvent).filter(NotificationEvent.parent_id == p.id).all()
            print(f"  Notifications: {len(notifications)}")
            for n in notifications:
                print(f"    [#] {n.title} - Status: {n.status}, Error: {n.error}")
    finally:
        db.close()

if __name__ == "__main__":
    check_tokens()
