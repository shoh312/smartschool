from pydantic import BaseModel


class LoginRequest(BaseModel):
    phone: str


class StudentLoginRequest(BaseModel):
    username: str
    password: str
