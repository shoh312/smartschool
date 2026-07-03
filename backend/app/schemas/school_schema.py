from typing import Optional

from pydantic import BaseModel


class ClassCreate(BaseModel):
    name: str
    grade: Optional[int] = None


class ClassResponse(BaseModel):
    id: int
    name: str
    grade: Optional[int] = None

    class Config:
        from_attributes = True


class CameraCreate(BaseModel):
    class_id: Optional[int] = None
    name: str
    ip_address: Optional[str] = None
    rtsp_url: Optional[str] = None
    is_active: bool = True
    detection_start_time: Optional[str] = None
    detection_end_time: Optional[str] = None
    detect_duration_seconds: Optional[int] = None
    wait_duration_minutes: Optional[int] = None


class CameraResponse(CameraCreate):
    id: int

    class Config:
        from_attributes = True
