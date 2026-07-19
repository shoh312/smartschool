from typing import Optional
from pydantic import BaseModel


class StudentResponse(BaseModel):
    id: int
    class_id: Optional[int] = None
    parent_id: Optional[int] = None
    class_name: Optional[str] = None
    parent_phone: Optional[str] = None
    parent_name: Optional[str] = None
    first_name: str
    last_name: str
    photo: Optional[str] = None
    face_encoding: Optional[str] = None
    is_active: bool

    class Config:
        from_attributes = True
