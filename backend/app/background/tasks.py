import asyncio
from datetime import date, timedelta

from app.database import SessionLocal
from app.models.attendance_model import Attendance
from app.models.class_model import Class
from app.models.student import Student
from app.notifications.firebase import send_pending_notifications
from app.services import analytics_service, diary_service
from app.services.attendance_service import (
    class_lesson_states,
    mark_absent_for_finished_lessons,
    mark_absent_students,
    mark_left_school_students,
)
from app.services.sync_outbox_service import enqueue_diary_event, enqueue_student_analytics_event
from app.utils.academic_calendar import current_quarter
from app.websocket.manager import manager


def run_attendance_jobs_once():
    db = SessionLocal()
    try:
        mark_absent_students(db)
        mark_absent_for_finished_lessons(db)
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

    class_names = {row.id: row.name for row in db.query(Class).all()}
    lesson_states = class_lesson_states(db)

    return {
        "type": "attendance_status",
        "items": [
            {
                "student_id": student.id,
                "first_name": student.first_name,
                "last_name": student.last_name,
                "class_id": student.class_id,
                "class_name": class_names.get(student.class_id),
                "class_lesson_state": lesson_states.get(student.class_id, "none"),
                "status": attendance.status if attendance else "not_detected",
                "attendance_date": today.isoformat(),
                "time_in": attendance.time_in.isoformat() if attendance and attendance.time_in else None,
                "time_out": attendance.time_out.isoformat() if attendance and attendance.time_out else None,
                "last_seen": attendance.last_seen.isoformat() if attendance and attendance.last_seen else None,
                "detected_at": attendance.detected_at.isoformat() if attendance and attendance.detected_at else None,
                "camera_id": attendance.camera_id if attendance else None,
            }
            for student, attendance in rows
        ],
    }


def _attendance_pass() -> dict:
    db = SessionLocal()
    try:
        mark_absent_students(db)
        mark_absent_for_finished_lessons(db)
        mark_left_school_students(db)
        send_pending_notifications(db)
        return _live_status_payload(db)
    finally:
        db.close()


async def attendance_background_loop():
    while True:
        payload = await asyncio.to_thread(_attendance_pass)
        await manager.broadcast(payload)
        await asyncio.sleep(30)


def _analytics_pass() -> None:
    db = SessionLocal()
    try:
        quarter = current_quarter()
        students = db.query(Student).filter(Student.is_active == True).all()
        for student in students:
            overview = analytics_service.build_student_overview(db, student, quarter)
            enqueue_student_analytics_event(db, student, overview)
        db.commit()
    finally:
        db.close()


async def analytics_sync_loop():
    while True:
        await asyncio.to_thread(_analytics_pass)
        await asyncio.sleep(300)


def _diary_pass() -> None:
    db = SessionLocal()
    try:
        class_ids = [row[0] for row in db.query(Class.id).all()]
        for class_id in class_ids:
            for on_date in (date.today(), date.today() + timedelta(days=1)):
                for entry in diary_service.resolve_diary_for_class(db, class_id, on_date):
                    enqueue_diary_event(
                        db,
                        class_id,
                        on_date,
                        entry["lesson_id"],
                        entry["subject"],
                        entry["room"],
                        entry["teacher_name"],
                        on_date.weekday(),
                        entry["start_time"],
                        entry["duration_minutes"],
                        entry["homework"],
                        entry["teacher_comment"],
                    )
        db.commit()
    finally:
        db.close()


async def diary_sync_loop():
    while True:
        await asyncio.to_thread(_diary_pass)
        await asyncio.sleep(900)
