from app.database import SessionLocal
from app.models.notification_model import NotificationEvent, DeviceToken
from app.models.parent_model import Parent
from app.models.student import Student
from app.models.attendance_model import Attendance
from app.models.class_model import Class
from app.models.camera_model import Camera

def register_tajik_parent():
    db = SessionLocal()
    try:
        phone_number = "+992928401115"
        
        # Check if parent already exists
        existing_parent = db.query(Parent).filter(Parent.phone == phone_number).first()
        if existing_parent:
            print(f"Ota-ona allaqachon mavjud: ID={existing_parent.id}, Telefon={existing_parent.phone}")
            parent = existing_parent
        else:
            # Create a new parent for Tajikistan
            parent = Parent(
                full_name="Tojikistonlik Ota-ona", 
                phone=phone_number
            )
            db.add(parent)
            db.commit()
            db.refresh(parent)
            print(f"Yangi Tojikistonlik ota-ona yaratildi: ID={parent.id}, Telefon={parent.phone}")

        # Link to the first student if exists (optional cleanup of previous links)
        student = db.query(Student).first()
        if student:
            student.parent_id = parent.id
            db.commit()
            print(f"O'quvchi '{student.first_name}' ushbu ota-onaga bog'landi.")
        else:
            print("Bazada o'quvchilar topilmadi.")
            
    except Exception as e:
        print(f"Xatolik yuz berdi: {e}")
        import traceback
        traceback.print_exc()
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    register_tajik_parent()
