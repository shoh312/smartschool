from pydantic import BaseModel


class LoginRequest(BaseModel):
    phone: str
    # Optional so a parent registered before passwords existed can still be
    # recognised and sent through the set-password flow instead of being
    # turned away at a screen they have no credentials for.
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
