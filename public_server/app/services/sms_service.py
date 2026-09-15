
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
    if settings.sms_provider == "robita":
        try:
            from app.services.robita_sms import client, to_local_number

            ok, detail = client.send(to_local_number(phone), text)
            if not ok:
                _write_outbox(phone, text)
                logger.error("Robita send failed: %s", detail)
            return SmsResult(ok, detail)
        except Exception as exc:
            _write_outbox(phone, text)
            logger.exception("Robita send raised")
            return SmsResult(False, str(exc)[:200])

    if not settings.sms_gateway_url:
        _write_outbox(phone, text)
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
    except Exception as exc:
        logger.exception("SMS send failed")
        return SmsResult(False, str(exc)[:200])


OUTBOX_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))), "logs", "sms_outbox.log")


def _write_outbox(phone: str, text: str) -> None:
    try:
        os.makedirs(os.path.dirname(OUTBOX_PATH), exist_ok=True)
        line = "%s  %s  %s\n" % (
            datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            phone,
            text,
        )
        with open(OUTBOX_PATH, "a", encoding="utf-8") as handle:
            handle.write(line)
    except Exception:
        logger.exception("Could not write the SMS outbox")


def code_message(code: str) -> str:
    return "SmartFlow: рамзи тасдиқ %s. Ба касе нагӯед." % code


def invitation_message(code: str) -> str:
    return (
        "SmartFlow: фарзанди шумо ба мактаб сабт шуд. "
        "Барномаро кушоед, рақами телефонатонро нависед ва рамзи %s-ро ворид кунед." % code
    )
