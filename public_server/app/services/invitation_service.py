
import logging
from datetime import datetime

from sqlalchemy.orm import Session

from app.models.parent_model import Parent
from app.models.verification_code_model import VerificationCode
from app.services import verification_service as verification
from app.services.sms_service import invitation_message, send_sms

logger = logging.getLogger(__name__)


def needs_invitation(parent: Parent) -> bool:
    return not parent.password_hash


def send_invitation(db: Session, parent: Parent, *, now: datetime | None = None) -> bool:
    if not needs_invitation(parent):
        return False

    now = now or datetime.utcnow()
    recent = (
        db.query(VerificationCode)
        .filter(
            VerificationCode.phone == parent.phone,
            VerificationCode.created_at >= now - verification.RATE_WINDOW,
        )
        .count()
    )
    if not verification.may_send_code(recent):
        logger.info("Invitation skipped, rate limit: %s", parent.phone)
        return False

    code = verification.generate_code()
    salt = verification.new_salt()
    db.add(
        VerificationCode(
            phone=parent.phone,
            code_salt=salt,
            code_hash=verification.hash_secret(code, salt),
            expires_at=verification.expiry_from(now),
            attempts=0,
        )
    )
    db.flush()

    send_sms(parent.phone, invitation_message(code))
    return True
