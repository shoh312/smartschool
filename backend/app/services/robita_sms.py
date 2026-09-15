
import logging
import re
import threading

import requests

from app.utils.config import settings

logger = logging.getLogger(__name__)

TIMEOUT_SECONDS = 20

_LOGGED_OUT_MARKER = 'name="password"'


class RobitaClient:

    def __init__(self):
        self._session: requests.Session | None = None
        self._lock = threading.Lock()

    @property
    def base(self) -> str:
        return settings.sms_robita_base.rstrip("/")

    def _login(self) -> requests.Session:
        session = requests.Session()
        response = session.post(
            f"{self.base}/auth",
            data={
                "login": settings.sms_robita_login,
                "password": settings.sms_robita_password,
            },
            timeout=TIMEOUT_SECONDS,
        )
        response.raise_for_status()
        if _LOGGED_OUT_MARKER in response.text:
            raise RuntimeError("robita_login_rejected")
        return session

    def send(self, local_number: str, text: str) -> tuple[bool, str]:
        with self._lock:
            if self._session is None:
                self._session = self._login()
            session = self._session

            ok, detail = self._post_message(session, local_number, text)
            if detail != "session_expired":
                return ok, detail

            logger.info("Robita session expired, signing in again")
            self._session = self._login()
            return self._post_message(self._session, local_number, text)

    def _post_message(self, session: requests.Session, local_number: str, text: str) -> tuple[bool, str]:
        response = session.post(
            f"{self.base}/home",
            params={"page": "message", "send": "one_done"},
            data={
                "customer": local_number,
                "sender": settings.sms_robita_sender,
                "text": text,
                "plan": "now",
            },
            timeout=TIMEOUT_SECONDS,
        )
        response.raise_for_status()
        if _LOGGED_OUT_MARKER in response.text:
            return False, "session_expired"
        if "alert-danger" in response.text or "error" in response.text.lower():
            return False, _first_message(response.text) or "rejected"
        return True, "sent"


def _first_message(html: str) -> str:
    match = re.search(r'class="alert[^"]*"[^>]*>(.*?)</div>', html, re.S)
    if not match:
        return ""
    return re.sub(r"<[^>]+>", " ", match.group(1)).strip()[:200]


def to_local_number(phone: str) -> str:
    digits = "".join(character for character in phone if character.isdigit())
    return digits[-9:]


client = RobitaClient()
