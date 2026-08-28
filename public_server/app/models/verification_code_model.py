from datetime import datetime

from sqlalchemy import Column, Integer, String, TIMESTAMP

from app.database import Base


class VerificationCode(Base):
    """One SMS code sent to one phone.

    Rows are kept after use rather than deleted: the rate limiter counts how
    many codes a number asked for in the last hour, and every send costs the
    school real money. A consumed row still counts against that.

    The code itself is never stored -- only a salted hash of it, the same way
    a password would be. Anyone who can read this table can already read the
    parents' data, but a leaked *live* code is a working key to an account,
    and there is no reason for the database to hold one.
    """

    __tablename__ = "verification_codes"

    id = Column(Integer, primary_key=True, index=True)
    phone = Column(String, index=True, nullable=False)

    code_salt = Column(String, nullable=False)
    code_hash = Column(String, nullable=False)

    expires_at = Column(TIMESTAMP, nullable=False)

    # Wrong guesses against this code. A six-digit code is guessable in a
    # million tries; capping the attempts is what makes it a secret.
    attempts = Column(Integer, nullable=False, default=0)

    consumed_at = Column(TIMESTAMP)

    # Stamped by Python in UTC, deliberately, not by the database.
    #
    # Postgres `now()` here returns local time (UTC+5) while every check in
    # verification_service works in UTC, so a database-stamped row looked
    # five hours *newer* than it was: the rate limiter counted it as "sent
    # within the last hour" all afternoon and silently skipped every
    # invitation after the third. One clock, everywhere.
    created_at = Column(TIMESTAMP, default=datetime.utcnow)
