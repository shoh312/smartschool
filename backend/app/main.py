import asyncio
import threading

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import engine, Base, ensure_database_schema

from app.routers.auth_router import router as auth_router
from app.routers.attendance_router import router as attendance_router
from app.routers.notification_router import router as notification_router
from app.routers.school_router import router as school_router
from app.routers.student_router import router as student_router
from app.routers.websocket_router import router as websocket_router
from app.routers.stream_router import router as stream_router

from app.models.student import Student
from app.models.class_model import Class
from app.models.parent_model import Parent
from app.models.camera_model import Camera
from app.models.attendance_model import Attendance
from app.models.director_model import Director
from app.models.notification_model import DeviceToken, NotificationEvent
from app.background.tasks import attendance_background_loop
from app.database import SessionLocal
from app.services.auth_service import ensure_default_director
from app.ai.live_detection import start_detection_background

Base.metadata.create_all(bind=engine)
ensure_database_schema()

seed_db = SessionLocal()
try:
    ensure_default_director(seed_db)
finally:
    seed_db.close()

app = FastAPI(title="SmartSchool Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(student_router)
app.include_router(attendance_router)
app.include_router(notification_router)
app.include_router(school_router)
app.include_router(websocket_router)
app.include_router(stream_router)

@app.get("/")
def root():
    return {"message": "SmartSchool Backend Running"}


@app.on_event("startup")
async def start_background_tasks():
    asyncio.create_task(attendance_background_loop())
    threading.Thread(target=start_detection_background, daemon=True).start()
