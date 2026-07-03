from app.database import SessionLocal

from app.services.attendance_service import mark_absent_students

# =====================================================
# CHECK ABSENT
# =====================================================

def check_absent_students():

    db = SessionLocal()

    try:
        absent_records = mark_absent_students(db)
        for attendance in absent_records:
            print(f"[ABSENT] student_id={attendance.student_id}")

    finally:
        db.close()
