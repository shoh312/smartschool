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


class SchoolSettings(BaseModel):
    """The two switches a director owns for their whole school."""

    live_video_enabled: bool
    group_mode: bool

    class Config:
        from_attributes = True


class SchoolSettingsUpdate(BaseModel):
    live_video_enabled: Optional[bool] = None
    group_mode: Optional[bool] = None


class CameraPositionCreate(BaseModel):
    class_id: int
    start_time: str
    end_time: str
    # Defaults to the group's own name, which for an academy is
    # usually the subject anyway ("PYTHON 4").
    subject: Optional[str] = None
    # None means "every day", which is how most academy timetables run.
    day_of_week: Optional[int] = None


class CameraPositionResponse(BaseModel):
    id: int
    camera_id: int
    class_id: int
    class_name: Optional[str] = None
    subject: Optional[str] = None
    day_of_week: Optional[int] = None
    start_time: str
    end_time: str

    class Config:
        from_attributes = True
