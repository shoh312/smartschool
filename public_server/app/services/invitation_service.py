# -*- coding: utf-8 -*-
"""The message a parent gets when their child is registered.

The parent is not asked to go looking for the app; the app comes to them.
A director enters the child, the phone number reaches this server through
the sync, and the number is texted a code and told what to do with it.

What is deliberately *not* in that message is a password. An SMS is
permanent -- it sits in the inbox until the phone is wiped, and phones get
handed to children, repaired, and resold. So the message carries a code that
is dead in five minutes, and the parent chooses their own password on the
other side of it.
"""

import logging
from datetime import datetime

from sqlalchemy.orm import Session

from app.models.parent_model import Parent
from app.models.verification_code_model import VerificationCode
from app.services import verification_service as verification
from app.services.sms_service import invitation_message, send_sms

logger = logging.getLogger(__name__)


def needs_invitation(parent: Parent) -> bool:
    """A parent who has already chosen a password has nothing to accept."""
    return not parent.password_hash


def send_invitation(db: Session, parent: Parent, *, now: datetime | None = None) -> bool:
    """Texts one parent a fresh sign-up code. Returns whether a code was
    issued -- not whether the SMS arrived, which no gateway can promise.

    Shares the rate limiter with the parent-initiated flow on purpose: a
    director saving the same child twice, or a sync event replaying, must
    not turn into two messages and two charges.
    """
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
    # Flushed rather than committed: this runs inside the sync ingest's own
    # transaction, and an invitation must not be durable while the student
    # it was sent about is rolled back.
    db.flush()

    send_sms(parent.phone, invitation_message(code))
    return True
