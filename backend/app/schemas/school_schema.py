from typing import Optional

from pydantic import BaseModel


class ClassCreate(BaseModel):
    name: str
    grade: Optional[int] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    detect_duration_seconds: Optional[int] = None
    wait_duration_minutes: Optional[int] = None
    timetable: Optional[dict[str, list[dict]]] = None


class ClassResponse(BaseModel):
    id: int
    name: str
    grade: Optional[int] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    detect_duration_seconds: Optional[int] = None
    wait_duration_minutes: Optional[int] = None
    timetable: Optional[dict[str, list[dict]]] = None

    class Config:
        from_attributes = True


class CameraCreate(BaseModel):
    class_id: Optional[int] = None
    name: str
    ip_address: Optional[str] = None
    rtsp_url: Optional[str] = None
    is_active: bool = True


class CameraResponse(CameraCreate):
    id: int

    class Config:
        from_attributes = True
