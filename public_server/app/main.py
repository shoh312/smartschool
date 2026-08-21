from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import engine, Base, ensure_database_schema

from app.models.school_model import School
from app.models.parent_model import Parent
from app.models.student_model import Student
from app.models.grade_model import Grade
from app.models.attendance_model import AttendanceStatus
from app.models.notification_model import DeviceToken, NotificationEvent
from app.models.student_analytics_model import StudentAnalytics
from app.models.diary_model import DiaryEntry
from app.models.calendar_event_model import CalendarEvent
from app.models.announcement_model import Announcement
from app.models.material_model import (
    Material,
    MaterialAssignment,
    MaterialAttempt,
    MaterialBlock,
)

from app.routers.sync_router import router as sync_router
from app.routers.auth_router import router as auth_router
from app.routers.student_router import router as student_router
from app.routers.journal_router import router as journal_router
from app.routers.attendance_router import router as attendance_router
from app.routers.notification_router import router as notification_router
from app.routers.analytics_router import router as analytics_router
from app.routers.diary_router import router as diary_router
from app.routers.calendar_router import router as calendar_router
from app.routers.announcement_router import router as announcement_router
from app.routers.material_router import router as material_router
from app.background.reminder_worker import reminder_loop

Base.metadata.create_all(bind=engine)
ensure_database_schema()

app = FastAPI(title="SmartSchool Public Server")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(sync_router)
app.include_router(auth_router)
app.include_router(student_router)
app.include_router(journal_router)
app.include_router(attendance_router)
app.include_router(notification_router)
app.include_router(analytics_router)
app.include_router(diary_router)
app.include_router(calendar_router)
app.include_router(announcement_router)
app.include_router(material_router)


@app.on_event("startup")
async def start_background_tasks():
    import asyncio

    asyncio.create_task(reminder_loop())


@app.get("/")
def root():
    return {"message": "SmartSchool Public Server Running"}
