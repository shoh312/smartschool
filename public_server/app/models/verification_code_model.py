from datetime import datetime

from sqlalchemy import Column, Integer, String, TIMESTAMP

from app.database import Base


class VerificationCode(Base):

    __tablename__ = "verification_codes"

    id = Column(Integer, primary_key=True, index=True)
    phone = Column(String, index=True, nullable=False)

    code_salt = Column(String, nullable=False)
    code_hash = Column(String, nullable=False)

    expires_at = Column(TIMESTAMP, nullable=False)

    attempts = Column(Integer, nullable=False, default=0)

    consumed_at = Column(TIMESTAMP)

    created_at = Column(TIMESTAMP, default=datetime.utcnow)
