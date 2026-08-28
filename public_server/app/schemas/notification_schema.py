from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class DeviceTokenCreate(BaseModel):
    # parent_id is part of the request shape the existing Flutter client
    # sends, but (matching the local server's existing behavior) the
    # authenticated caller from the bearer token is the actual source of
    # truth -- this field is accepted and ignored, not trusted. Optional
    # because a pupil registering their own phone has no parent id to send.
    parent_id: int | None = None
    token: str
    platform: Optional[str] = None


class SchoolMessageCreate(BaseModel):
    """A message the school's own server wants a parent to see in the app.

    Used for the sign-in details of a second, third or fourth child: the
    first child's arrive by SMS because the parent has no app yet, and every
    one after that arrives here instead -- cheaper, and it does not leave a
    password sitting in an inbox forever.
    """

    parent_phone: str
    title: str
    body: str
    event_type: str = "school_message"


class NotificationResponse(BaseModel):
    id: int
    parent_id: Optional[int] = None
    student_id: Optional[int] = None
    event_type: str
    title: str
    body: str
    status: str
    sent_at: Optional[datetime] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True
