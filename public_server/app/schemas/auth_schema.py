from pydantic import BaseModel


class LoginRequest(BaseModel):
    phone: str
    password: str | None = None


class RequestCodeRequest(BaseModel):
    phone: str


class VerifyCodeRequest(BaseModel):
    phone: str
    code: str


class SetPasswordRequest(BaseModel):
    setup_token: str
    full_name: str
    password: str


class StudentLoginRequest(BaseModel):
    username: str
    password: str
