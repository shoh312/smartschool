# -*- coding: utf-8 -*-
"""Sending SMS through sms.robita.tj.

Robita has no API -- it has a web panel a person logs into and types a
message. So this drives that panel: one POST to sign in, which returns a
PHPSESSID, then one POST per message to the same form the "Отправить" button
submits.

That makes it fragile in a way a real API is not: if Robita redesigns the
page, this stops working. Two things keep the damage small -- the session is
re-established automatically when it lapses, and a failed send is reported
rather than raised, so a parent's sign-up never fails because an SMS panel
changed its HTML.

The form, as of August 2026:

    POST /auth                              login, password
    POST /home?page=message&send=one_done   customer, sender, text, plan

`customer` is the nine-digit local number -- the field is maxlength=9, so
the 992 country code has to come off. `sender` is the account's registered
sender id (0175 = "SmartFlow"), and `plan=now` means send immediately rather
than schedule.
"""

import logging
import re
import threading

import requests

from app.utils.config import settings

logger = logging.getLogger(__name__)

TIMEOUT_SECONDS = 20

# Present on every page of the panel *except* when the session has lapsed and
# the login form is served instead. Cheaper and more stable than checking for
# a success banner, whose wording is not ours to rely on.
_LOGGED_OUT_MARKER = 'name="password"'


class RobitaClient:
    """One shared, lazily authenticated session.

    Locked because the sync ingest can invite two parents at once, and two
    threads logging in at the same time would each overwrite the other's
    cookie -- leaving one of them posting a message with a dead session.
    """

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

            # One retry, with a fresh session: the panel's PHP session times
            # out on its own schedule, and the first message after a quiet
            # night would otherwise always fail.
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
    """Pulls the panel's own banner text out, for the log."""
    match = re.search(r'class="alert[^"]*"[^>]*>(.*?)</div>', html, re.S)
    if not match:
        return ""
    return re.sub(r"<[^>]+>", " ", match.group(1)).strip()[:200]


def to_local_number(phone: str) -> str:
    """`992987644002` -> `987644002`.

    The panel's field is nine characters wide and rejects anything longer,
    while everything on our side stores numbers country-code first.
    """
    digits = "".join(character for character in phone if character.isdigit())
    return digits[-9:]


client = RobitaClient()
