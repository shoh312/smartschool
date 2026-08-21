from sqlalchemy import Boolean, Column, Integer, String, TIMESTAMP
from sqlalchemy.sql import func

from app.database import Base


class Director(Base):
    __tablename__ = "directors"

    id = Column(Integer, primary_key=True, index=True)
    school_id = Column(Integer, nullable=True, index=True)
    full_name = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False, index=True)
    hashed_password = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)

    # Set while the account still carries a password nobody chose -- the
    # seeded default. The app refuses to go any further than the change
    # form until it is cleared, because a school running on a password
    # printed in the source code is not a school with an account system.
    must_change_password = Column(Boolean, nullable=False, server_default="false")
    is_superadmin = Column(Boolean, default=False, nullable=False, server_default="false")
    created_at = Column(TIMESTAMP, server_default=func.now())
