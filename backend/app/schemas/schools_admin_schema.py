from typing import Optional

from pydantic import BaseModel


class SchoolCreate(BaseModel):
    name: str
    address: Optional[str] = None
    phone: Optional[str] = None


class SchoolResponse(BaseModel):
    id: int
    name: str
    address: Optional[str] = None
    phone: Optional[str] = None
    is_active: bool

    class Config:
        from_attributes = True
