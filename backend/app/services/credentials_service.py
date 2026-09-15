
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
    except Exception:
        logger.exception("Credentials notification raised")
        return False
