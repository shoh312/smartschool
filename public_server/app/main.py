from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import engine, Base

from app.models.school_model import School
from app.models.parent_model import Parent
from app.models.student_model import Student
from app.models.grade_model import Grade
from app.models.attendance_model import AttendanceStatus
from app.models.notification_model import DeviceToken, NotificationEvent

from app.routers.sync_router import router as sync_router
from app.routers.auth_router import router as auth_router
from app.routers.student_router import router as student_router
from app.routers.journal_router import router as journal_router
from app.routers.attendance_router import router as attendance_router
from app.routers.notification_router import router as notification_router

Base.metadata.create_all(bind=engine)

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


@app.get("/")
def root():
    return {"message": "SmartSchool Public Server Running"}
