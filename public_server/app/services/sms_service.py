# -*- coding: utf-8 -*-
"""Sending one SMS, through whichever gateway the school has a contract with.

Deliberately not written against a particular provider. Tajik gateways
(operators and the aggregators in front of them) almost all expose the same
shape: one HTTP call with the number, the text, and a login of some kind.
So the provider lives entirely in environment variables, and switching from
one to another is a config change rather than a code change:

    SMS_GATEWAY_URL=https://gateway.example.tj/send
    SMS_GATEWAY_METHOD=POST                 # or GET
    SMS_GATEWAY_BODY={"login":"$LOGIN","password":"$PASSWORD","phone":"{phone}","text":"{text}"}
    SMS_GATEWAY_HEADERS={"Content-Type":"application/json"}
    SMS_SENDER_NAME=SmartFlow

`{phone}` and `{text}` are filled in per message; everything else is copied
through as written.

With no URL configured the message is appended to logs/sms_outbox.log instead
of being sent. That is the mode the school runs in until the contract is
signed: the whole sign-up flow works, and whoever is setting the phones up
reads the code out of that file.
"""

import datetime
import json
import logging
import os
import urllib.parse
import urllib.request

from app.utils.config import settings

logger = logging.getLogger(__name__)

TIMEOUT_SECONDS = 10


class SmsResult:
    def __init__(self, sent: bool, detail: str = ""):
        self.sent = sent
        self.detail = detail


def _render(template: str, phone: str, text: str) -> str:
    return template.replace("{phone}", phone).replace("{text}", text)


def send_sms(phone: str, text: str) -> SmsResult:
    """Never raises. A gateway being down must not turn into a 500 on a
    parent's sign-up screen -- the caller decides what to tell them.
    """
    if settings.sms_provider == "robita":
        try:
            from app.services.robita_sms import client, to_local_number

            ok, detail = client.send(to_local_number(phone), text)
            if not ok:
                # Kept in the outbox when it did not go out, so the code is
                # still recoverable by hand instead of lost.
                _write_outbox(phone, text)
                logger.error("Robita send failed: %s", detail)
            return SmsResult(ok, detail)
        except Exception as exc:  # noqa: BLE001 -- see the docstring
            _write_outbox(phone, text)
            logger.exception("Robita send raised")
            return SmsResult(False, str(exc)[:200])

    if not settings.sms_gateway_url:
        _write_outbox(phone, text)
        # ascii() because this console is cp1251 and a Cyrillic message in a
        # log line crashes the process on this machine -- see the note in
        # the project's memory about that trap.
        logger.warning("SMS gateway not configured; code for %s: %s", phone, ascii(text))
        return SmsResult(False, "gateway_not_configured")

    try:
        url = _render(settings.sms_gateway_url, phone, urllib.parse.quote(text))
        headers = json.loads(settings.sms_gateway_headers) if settings.sms_gateway_headers else {}

        data = None
        if settings.sms_gateway_method.upper() == "POST":
            data = _render(settings.sms_gateway_body, phone, text).encode("utf-8")

        request = urllib.request.Request(
            url,
            data=data,
            headers=headers,
            method=settings.sms_gateway_method.upper(),
        )
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            body = response.read().decode("utf-8", "replace")[:500]
            if 200 <= response.status < 300:
                return SmsResult(True, body)
            return SmsResult(False, "http_%s: %s" % (response.status, body))
    except Exception as exc:  # noqa: BLE001 -- see the docstring
        logger.exception("SMS send failed")
        return SmsResult(False, str(exc)[:200])


OUTBOX_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))), "logs", "sms_outbox.log")


def _write_outbox(phone: str, text: str) -> None:
    """Where messages go while there is no gateway.

    Not a debugging leftover -- it is what makes the sign-up flow usable
    before the SMS contract is signed: whoever is setting the phones up
    reads the code from this file and reads it out to the parent. It stops
    being written the moment SMS_GATEWAY_URL is set.

    Codes live five minutes, so what accumulates here is a list of expired
    numbers; still, it belongs on the server's own disk and nowhere else.
    """
    try:
        os.makedirs(os.path.dirname(OUTBOX_PATH), exist_ok=True)
        line = "%s  %s  %s\n" % (
            datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            phone,
            text,
        )
        with open(OUTBOX_PATH, "a", encoding="utf-8") as handle:
            handle.write(line)
    except Exception:  # noqa: BLE001 -- an unwritable log must not fail a sign-up
        logger.exception("Could not write the SMS outbox")


def code_message(code: str) -> str:
    """Tajik, because that is what the parents read.

    The app name is in it on purpose: a bare six-digit number from an unknown
    sender is exactly what a scam looks like.
    """
    return "SmartFlow: рамзи тасдиқ %s. Ба касе нагӯед." % code


def invitation_message(code: str) -> str:
    """Sent when a child is registered, to a parent who has never opened the
    app. Says what happened and what to do next -- a bare code to someone
    expecting nothing is indistinguishable from a scam.
    """
    return (
        "SmartFlow: фарзанди шумо ба мактаб сабт шуд. "
        "Барномаро кушоед, рақами телефонатонро нависед ва рамзи %s-ро ворид кунед." % code
    )
