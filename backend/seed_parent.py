from app.database import SessionLocal
# Import all models to ensure they are registered in Base.metadata
from app.models.notification_model import NotificationEvent, DeviceToken
from app.models.parent_model import Parent
from app.models.student import Student
from app.models.attendance_model import Attendance
from app.models.class_model import Class
from app.models.camera_model import Camera

def seed_parent_student():
    db = SessionLocal()
    try:
        # Create a new parent
        parent = Parent(
            full_name="Abduvohidov Akmal", 
            phone="+998901234567"
        )
        db.add(parent)
        db.commit()
        db.refresh(parent)
        print(f"Yangi ota-ona yaratildi: ID={parent.id}, Ism={parent.full_name}")

        # Link to the first student if exists
        student = db.query(Student).first()
        if student:
            student.parent_id = parent.id
            db.commit()
            print(f"O'quvchi '{student.first_name}' ota-onaga bog'landi (Parent ID: {parent.id})")
        else:
            print("Bazada o'quvchilar topilmadi, bog'lash imkoni bo'lmadi.")
            
    except Exception as e:
        print(f"Xatolik yuz berdi: {e}")
        import traceback
        traceback.print_exc()
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    seed_parent_student()
