import asyncio
import threading

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.database import (
    engine,
    Base,
    ensure_database_schema,
    ensure_default_school_and_backfill,
    ensure_grade_quarter_backfill,
    ensure_grade_school_year_backfill,
    ensure_rooms_backfill,
)

from app.routers.auth_router import router as auth_router
from app.routers.attendance_router import router as attendance_router
from app.routers.notification_router import router as notification_router
from app.routers.school_router import router as school_router

from app.routers.schools_admin_router import router as schools_admin_router
from app.routers.student_router import router as student_router
from app.routers.student_router import parent_router as parent_student_router
from app.routers.teacher_router import router as teacher_router
from app.routers.journal_router import router as journal_router
from app.routers.websocket_router import router as websocket_router
from app.routers.stream_router import router as stream_router
from app.routers.sync_status_router import router as sync_status_router
from app.routers.lesson_router import router as lesson_router
from app.routers.analytics_router import router as analytics_router
from app.routers.diary_router import router as diary_router
from app.routers.calendar_router import router as calendar_router
from app.routers.announcement_router import router as announcement_router
from app.routers.material_router import router as material_router

from app.models.student import Student
from app.models.class_model import Class
from app.models.parent_model import Parent
from app.models.camera_model import Camera

from app.models.attendance_model import Attendance
from app.models.director_model import Director
from app.models.school_model import School
from app.models.teacher_model import Teacher, TeacherClass
from app.models.journal_model import Grade
from app.models.notification_model import DeviceToken, NotificationEvent
from app.models.sync_outbox_model import SyncOutboxEntry
from app.models.lesson_model import Lesson
from app.models.lesson_attendance_model import LessonAttendance
from app.models.lesson_log_model import LessonLog
from app.models.school_event_model import SchoolEvent
from app.models.announcement_model import Announcement
from app.models.material_model import (
    Material,
    MaterialAssignment,
    MaterialAttempt,
    MaterialBlock,
)
from app.background.tasks import attendance_background_loop, analytics_sync_loop, diary_sync_loop
from app.background.sync_worker import sync_background_loop
from app.background.attempt_pull_worker import attempt_pull_loop
from app.database import SessionLocal
from app.discovery import start_discovery_responder
from app.utils.config import settings
from app.services.auth_service import ensure_default_director
from app.ai.live_detection import start_detection_background

Base.metadata.create_all(bind=engine)
ensure_database_schema()
default_school_id = ensure_default_school_and_backfill()
ensure_rooms_backfill()
ensure_grade_quarter_backfill()
ensure_grade_school_year_backfill()

seed_db = SessionLocal()
try:
    ensure_default_director(seed_db, default_school_id=default_school_id)
finally:
    seed_db.close()

app = FastAPI(title="SmartSchool Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    # No cookies are used (auth is a Bearer token in the Authorization header), so
    # allow_credentials must stay False -- browsers reject "*" origins combined with
    # allow_credentials=True, and there's no fixed origin since this runs on varying
    # school-local-network IPs.
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(student_router)
app.include_router(parent_student_router)
app.include_router(attendance_router)
app.include_router(notification_router)
app.include_router(school_router)

app.include_router(schools_admin_router)
app.include_router(teacher_router)
app.include_router(journal_router)
app.include_router(websocket_router)
app.include_router(stream_router)
app.include_router(sync_status_router)
app.include_router(lesson_router)
app.include_router(analytics_router)
app.include_router(diary_router)
app.include_router(calendar_router)
app.include_router(announcement_router)
app.include_router(material_router)

@app.exception_handler(RequestValidationError)
async def validation_error_handler(request: Request, exc: RequestValidationError):
    """Turns a rejected form back into a message the app can show.

    FastAPI's own handler echoes the offending input back in the error, and
    on a multipart request that input is the uploaded photo -- megabytes of
    JPEG. Encoding it as JSON calls bytes.decode(), which dies on the first
    byte that is not UTF-8, and the clean 422 ("parent_phone is required")
    becomes an opaque 500 the director sees as "error" with nothing to act
    on. Registering a student is the one form in the app that sends a file,
    which is why this only ever bit there.

    So the input is dropped and only the location and the reason are kept.
    """
    safe = [
        {"loc": [str(part) for part in error.get("loc", [])],
         "msg": error.get("msg", ""),
         "type": error.get("type", "")}
        for error in exc.errors()
    ]
    return JSONResponse(status_code=422, content={"detail": safe})


@app.get("/")
def root():
    return {"message": "SmartSchool Backend Running"}


@app.on_event("startup")
async def start_background_tasks():
    from app.realtime import set_main_loop

    # Lets the sync camera-detection thread and FastAPI's sync-endpoint
    # threadpool schedule work (websocket broadcasts, waking the sync
    # worker) onto this loop -- see app/realtime.py.
    set_main_loop(asyncio.get_running_loop())

    asyncio.create_task(attendance_background_loop())
    asyncio.create_task(analytics_sync_loop())
    asyncio.create_task(diary_sync_loop())
    asyncio.create_task(sync_background_loop())
    # The one loop that reads FROM the Public Server: pupils' finished test
    # work, which is written there because that's where the pupil is.
    asyncio.create_task(attempt_pull_loop())
    asyncio.create_task(start_discovery_responder(settings.school_server_port))
    threading.Thread(target=start_detection_background, daemon=True).start()
