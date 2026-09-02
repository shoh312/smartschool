import asyncio
from datetime import date, timedelta

from app.database import SessionLocal
from app.models.attendance_model import Attendance
from app.models.class_model import Class
from app.models.student import Student
from app.notifications.firebase import send_pending_notifications
from app.services import analytics_service, diary_service
from app.services.attendance_service import (
    classes_in_session_now,
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

    # Class names come from here rather than being joined on the client.
    #
    # The desktop dashboard groups the day by class, and it used to do that
    # by looking each pupil up in the list the app had loaded separately.
    # The two disagreed -- that list is loaded for a different purpose and
    # does not always hold every pupil -- so classes showed 0 present while
    # the header counted 31. One source, one answer.
    class_names = {row.id: row.name for row in db.query(Class).all()}
    # Which classes are actually in a lesson right now. The desktop dashboard
    # uses it to show an academy only the groups that are in the building --
    # a group whose lesson finished at four should not still be listed at six.
    in_session = classes_in_session_now(db)

    return {
        "type": "attendance_status",
        "items": [
            {
                "student_id": student.id,
                "first_name": student.first_name,
                "last_name": student.last_name,
                "class_id": student.class_id,
                "class_name": class_names.get(student.class_id),
                "class_in_session": student.class_id in in_session,
                "status": attendance.status if attendance else "not_detected",
                "attendance_date": today.isoformat(),
                "time_in": attendance.time_in.isoformat() if attendance and attendance.time_in else None,
                "time_out": attendance.time_out.isoformat() if attendance and attendance.time_out else None,
                "last_seen": attendance.last_seen.isoformat() if attendance and attendance.last_seen else None,
                # The last resort for "when". A pupil marked present from
                # somewhere other than the camera can carry no time_in and no
                # last_seen at all, and the desktop dashboard then had no way
                # to place them on the morning's curve -- it showed an empty
                # panel under a header counting thirty-one arrivals.
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
        # Off the event loop. These are synchronous SQLAlchemy calls that
        # sweep every school's attendance, and awaiting nothing while they
        # run meant the loop simply stopped for as long as they took --
        # every request, every websocket, the live video included. Measured
        # against the camera, the picture stalled up to three seconds at a
        # time while the capture thread beside it kept producing 20 frames a
        # second that nothing was free to send.
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
    """Every 5 minutes, recomputes and re-syncs every active student's
    ranking snapshot to the Public Server. The reactive push in
    journal_router covers the graded student themselves instantly, but a
    classmate's new grade also shifts this student's class/parallel/school
    rank -- this periodic sweep is what keeps that number from going stale
    for everyone who *wasn't* the one just graded.
    """
    while True:
        # Threaded for the same reason as the attendance sweep: this rebuilds
        # an overview for every active student in the school, and it ran
        # inline on the event loop.
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
    """Every 15 minutes, pushes today's and tomorrow's resolved diary for
    every class that has at least one Lesson slot. A homework/comment write
    already pushes immediately (see diary_router.py's PATCH), but this sweep
    is what lets a parent see tomorrow's schedule (subject/teacher/room/time)
    even before any teacher has written a single homework note for it.
    """
    while True:
        # Threaded like the other sweeps -- this one walks every class and
        # resolves two days of diary for each.
        await asyncio.to_thread(_diary_pass)
        await asyncio.sleep(900)
