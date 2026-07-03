from typing import Optional

from pydantic import BaseModel, EmailStr


class DirectorCreate(BaseModel):
    school_id: Optional[int] = None
    full_name: str
    email: EmailStr
    password: str


class DirectorLogin(BaseModel):
    email: EmailStr
    password: str


class DirectorResponse(BaseModel):
    id: int
    school_id: Optional[int] = None
    full_name: str
    email: EmailStr
    is_active: bool

    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_type: str
    director: Optional[DirectorResponse] = None

class LoginRequest(BaseModel):
    phone: str
    firebase_token: Optional[str] = None
    platform: Optional[str] = None


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    parent_id: int
    full_name: Optional[str] = None
    phone: str

class ParentRegisterRequest(BaseModel):
    phone: str
    full_name: str
    firebase_token: Optional[str] = None
    platform: Optional[str] = None
