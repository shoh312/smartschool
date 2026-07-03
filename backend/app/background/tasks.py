import asyncio
from datetime import date

from app.database import SessionLocal
from app.models.attendance_model import Attendance
from app.models.student import Student
from app.notifications.firebase import send_pending_notifications
from app.services.attendance_service import (
    mark_absent_students,
    mark_left_school_students,
)
from app.websocket.manager import manager


def run_attendance_jobs_once():
    db = SessionLocal()
    try:
        mark_absent_students(db)
        mark_left_school_students(db)
        send_pending_notifications(db)
    finally:
        db.close()


def _live_status_payload(db):
    today = date.today()
    rows = db.query(Student, Attendance).outerjoin(
        Attendance,
        (Attendance.student_id == Student.id)
        & (Attendance.attendance_date == today),
    ).filter(Student.is_active == True).all()

    return {
        "type": "attendance_status",
        "items": [
            {
                "student_id": student.id,
                "first_name": student.first_name,
                "last_name": student.last_name,
                "status": attendance.status if attendance else "not_detected",
                "attendance_date": today.isoformat(),
                "time_in": attendance.time_in.isoformat() if attendance and attendance.time_in else None,
                "time_out": attendance.time_out.isoformat() if attendance and attendance.time_out else None,
                "last_seen": attendance.last_seen.isoformat() if attendance and attendance.last_seen else None,
                "camera_id": attendance.camera_id if attendance else None,
            }
            for student, attendance in rows
        ],
    }


async def attendance_background_loop():
    while True:
        db = SessionLocal()
        try:
            mark_absent_students(db)
            mark_left_school_students(db)
            send_pending_notifications(db)
            await manager.broadcast(_live_status_payload(db))
        finally:
            db.close()

        await asyncio.sleep(30)
