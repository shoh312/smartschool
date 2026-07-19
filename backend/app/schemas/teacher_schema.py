from typing import Optional

from pydantic import BaseModel, EmailStr


class TeacherCreate(BaseModel):
    full_name: str
    email: EmailStr
    password: str
    subject: Optional[str] = None


class TeacherLogin(BaseModel):
    email: EmailStr
    password: str


class TeacherResponse(BaseModel):
    id: int
    school_id: Optional[int] = None
    full_name: str
    email: EmailStr
    subject: Optional[str] = None
    is_active: bool

    class Config:
        from_attributes = True


class TeacherTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    teacher: TeacherResponse


class ClassAssignmentCreate(BaseModel):
    class_id: int
    subject: str


class ClassAssignmentResponse(BaseModel):
    id: int
    class_id: int
    subject: Optional[str] = None
    class_name: Optional[str] = None

    class Config:
        from_attributes = True


class ClassSubjectResponse(BaseModel):
    id: int
    subject: Optional[str] = None
    teacher_id: int
    teacher_name: str

    class Config:
        from_attributes = True
