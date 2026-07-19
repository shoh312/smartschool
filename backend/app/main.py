import asyncio
import threading

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import engine, Base, ensure_database_schema, ensure_default_school_and_backfill

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
from app.background.tasks import attendance_background_loop
from app.background.sync_worker import sync_background_loop
from app.database import SessionLocal
from app.discovery import start_discovery_responder
from app.services.auth_service import ensure_default_director
from app.ai.live_detection import start_detection_background

Base.metadata.create_all(bind=engine)
ensure_database_schema()
default_school_id = ensure_default_school_and_backfill()

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

@app.get("/")
def root():
    return {"message": "SmartSchool Backend Running"}


@app.on_event("startup")
async def start_background_tasks():
    asyncio.create_task(attendance_background_loop())
    asyncio.create_task(sync_background_loop())
    asyncio.create_task(start_discovery_responder())
    threading.Thread(target=start_detection_background, daemon=True).start()
