from datetime import datetime

from sqlalchemy import Column, Integer, String, JSON, TIMESTAMP
from sqlalchemy.sql import func

from app.database import Base


class SyncOutboxEntry(Base):
    """A queued event waiting to be pushed to the Public Server.

    Written in the SAME transaction as the source-of-truth write (grade,
    attendance, student), so a crash right after a commit never loses an
    event -- either both are committed or neither is. The background worker
    (app/background/sync_worker.py) drains this table separately and never
    marks an entry "sent" until the Public Server actually confirms it, and
    never gives up permanently on a failure (see the RTSP camera-retry bug
    fixed earlier this session for the failure mode this must avoid).
    """

    __tablename__ = "sync_outbox"

    id = Column(Integer, primary_key=True, index=True)
    entity_type = Column(String, nullable=False, index=True)  # student | grade | attendance
    entity_id = Column(Integer, nullable=False)
    operation = Column(String, nullable=False, default="upsert")  # upsert | delete | deactivate
    payload = Column(JSON, nullable=False)
    status = Column(String, nullable=False, default="pending", index=True)  # pending | sent
    attempts = Column(Integer, nullable=False, default=0)
    last_error = Column(String, nullable=True)
    # Python-side default (not server_default=func.now()) deliberately -- this
    # column is compared against datetime.utcnow() in sync_worker.py, and
    # Postgres's own now() reflects the server's configured local timezone
    # (UTC+5 here), not UTC. Mixing the two made every row's default
    # "next attempt" look like it was hours in the future relative to the
    # Python-side comparison, so nothing was ever eligible to send.
    next_attempt_at = Column(TIMESTAMP, default=datetime.utcnow, index=True)
    created_at = Column(TIMESTAMP, server_default=func.now())
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())
