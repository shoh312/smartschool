# -*- coding: utf-8 -*-
"""Telling a parent their child's sign-in details.

The parent gets into the app on their own: they press Register, type their
number, receive a code, and choose their own password. Nothing the school
sends is a credential for *them*.

What the school does have to hand over is the pupil's login, which the pupil
cannot invent for themselves -- and that goes into the parent's app as a
notification, not by SMS. An earlier version texted school-issued passwords
for both of them as well, which meant credentials arriving by two routes
while the app still asked the parent to choose a third. It was confusing
enough to be unusable, and a password in an inbox outlives the phone.

Sent from the school's own server rather than through the sync outbox: the
message carries a password, and outbox rows are kept after they are sent.
This way the plaintext exists in exactly one place -- the notification the
parent is meant to read.
"""

import logging

import requests

from app.models.parent_model import Parent
from app.models.student import Student
from app.utils.config import settings

logger = logging.getLogger(__name__)


def in_app_message(
    *,
    student_name: str,
    student_username: str,
    student_password: str,
) -> tuple[str, str]:
    """Written in Tajik and at full length -- a push costs nothing per
    character, unlike the 70 a Cyrillic SMS allows.

    The parent's own login is deliberately absent: they are reading this
    while signed in with it.
    """
    title = "Маълумоти вуруди %s" % student_name
    body = (
        "Фарзандатон %s ба система илова шуд.\n"
        "Логин: %s\n"
        "Парол: %s\n"
        "Бо ин маълумот фарзандатон метавонад ба барнома дарояд."
        % (student_name, student_username, student_password)
    )
    return title, body


def send_credentials_notification(
    *,
    parent: Parent,
    student: Student,
    student_username: str,
    student_password: str,
) -> bool:
    """Never raises: a school must still be able to register a child when the
    Public Server is unreachable. The message simply waits -- it is sent
    again by nobody, so a failure here means the director reads the login off
    the pupil list instead.
    """
    if not settings.public_server_api_key:
        logger.warning("No public server key; credentials notification not sent")
        return False

    title, body = in_app_message(
        student_name=student.first_name,
        student_username=student_username,
        student_password=student_password,
    )

    try:
        response = requests.post(
            "%s/notifications/school-message" % settings.public_server_url.rstrip("/"),
            json={
                "parent_phone": parent.phone,
                "title": title,
                "body": body,
                "event_type": "student_credentials",
            },
            headers={"X-School-Key": settings.public_server_api_key},
            timeout=15,
        )
        if response.status_code >= 300:
            logger.error(
                "Credentials notification refused: %s %s",
                response.status_code,
                response.text[:200],
            )
            return False
        return True
    except Exception:  # noqa: BLE001 -- see the docstring
        logger.exception("Credentials notification raised")
        return False
