# -*- coding: utf-8 -*-
"""Invites the parents who were already in the database when passwords
arrived.

New parents are invited by the sync itself, the moment their child is
registered (see invitation_service). The ones registered before that -- 57 of
them at the time of writing -- never pass through that branch, and they are
exactly the families already using the app, so they are the ones who most
need telling.

    python scripts/invite_parents.py            # dry run, sends nothing
    python scripts/invite_parents.py --apply    # sends
    python scripts/invite_parents.py --apply --phone 992987644002   # just one

Each message costs the school money, so the dry run prints the exact list
first and the hourly per-number limit still applies.
"""

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.models.school_model import School  # noqa: E402,F401  mapper registration
from app.models.notification_model import DeviceToken  # noqa: E402,F401
from app.models.student_model import Student  # noqa: E402
from app.models.parent_model import Parent  # noqa: E402
from app.database import SessionLocal  # noqa: E402
from app.services.invitation_service import needs_invitation, send_invitation  # noqa: E402
from app.utils.config import settings  # noqa: E402

# Gateways throttle; a burst of sixty is how a sender gets blocked.
PAUSE_SECONDS = 1.0


def safe(text):
    """Windows consoles here are cp1251, and printing a Tajik name straight
    out crashes the script mid-run -- after some messages have already been
    sent. Anything unprintable is replaced rather than raised.
    """
    return str(text or "").encode(sys.stdout.encoding or "utf-8", "replace").decode(
        sys.stdout.encoding or "utf-8", "replace"
    )


def main():
    apply_changes = "--apply" in sys.argv
    only_phone = None
    if "--phone" in sys.argv:
        only_phone = sys.argv[sys.argv.index("--phone") + 1]

    db = SessionLocal()
    try:
        query = db.query(Parent)
        if only_phone:
            query = query.filter(Parent.phone == only_phone)

        candidates = []
        for parent in query.order_by(Parent.id).all():
            if not needs_invitation(parent):
                continue
            children = db.query(Student).filter(
                Student.parent_id == parent.id,
                Student.is_active == True,  # noqa: E712
            ).count()
            # No active child means nothing to show them once they sign in.
            if children == 0:
                continue
            candidates.append((parent, children))

        print("Paroli yo'q, faol farzandi bor ota-onalar: %d" % len(candidates))
        for parent, children in candidates:
            print("   %-14s %s (%d farzand)" % (parent.phone, safe(parent.full_name), children))

        if not settings.sms_gateway_url and settings.sms_provider != "robita":
            print("\nDIQQAT: SMS shlyuzi sozlanmagan -- xabarlar logs/sms_outbox.log ga yoziladi.")

        if not candidates:
            return
        if not apply_changes:
            print("\nSinov rejimi -- hech narsa yuborilmadi. Yuborish uchun: --apply")
            return

        sent = 0
        for parent, _ in candidates:
            if send_invitation(db, parent):
                sent += 1
                print("yuborildi: %s" % parent.phone)
            else:
                print("o'tkazib yuborildi (chegara yoki paroli bor): %s" % parent.phone)
            db.commit()
            time.sleep(PAUSE_SECONDS)

        print("\nJami yuborildi: %d" % sent)
    finally:
        db.close()


if __name__ == "__main__":
    main()
