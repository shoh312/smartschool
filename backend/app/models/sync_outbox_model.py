from datetime import datetime

from sqlalchemy import Column, Integer, String, JSON, TIMESTAMP
from sqlalchemy.sql import func

from app.database import Base


class SyncOutboxEntry(Base):

    __tablename__ = "sync_outbox"

    id = Column(Integer, primary_key=True, index=True)
    entity_type = Column(String, nullable=False, index=True)
    entity_id = Column(Integer, nullable=False)
    operation = Column(String, nullable=False, default="upsert")
    payload = Column(JSON, nullable=False)
    status = Column(String, nullable=False, default="pending", index=True)
    attempts = Column(Integer, nullable=False, default=0)
    last_error = Column(String, nullable=True)
    next_attempt_at = Column(TIMESTAMP, default=datetime.utcnow, index=True)
    created_at = Column(TIMESTAMP, server_default=func.now())
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())
