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
    """The switches a director owns for their whole school."""

    live_video_enabled: bool
    group_mode: bool
    # Master stop for Robita SMS (credential texts, attendance-SMS fallback)
    # -- for a school whose schedule is entered but has no camera watching
    # it yet, so absence texts can be silenced without disabling the
    # schedule itself.
    sms_enabled: bool
    # Pauses attendance recording (both "present" from a camera and
    # "absent" from the day-end sweep) for the whole school -- for the same
    # gap between "schedule is entered" and "a camera is actually watching
    # it" that sms_enabled covers, but for the underlying data rather than
    # just the notification.
    is_active: bool

    class Config:
        from_attributes = True


class SchoolSettingsUpdate(BaseModel):
    live_video_enabled: Optional[bool] = None
    group_mode: Optional[bool] = None
    sms_enabled: Optional[bool] = None
    is_active: Optional[bool] = None


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
