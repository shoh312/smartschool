import os

from dotenv import load_dotenv

load_dotenv()


class Settings:
    auth_secret = os.getenv("SMARTSCHOOL_PUBLIC_AUTH_SECRET", "change-this-secret")
    notifications_enabled = os.getenv("NOTIFICATIONS_ENABLED", "true").strip().lower() not in ("0", "false", "no", "off")
    firebase_credentials = os.getenv("FIREBASE_CREDENTIALS")

    sms_gateway_url = os.getenv("SMS_GATEWAY_URL", "")
    sms_gateway_method = os.getenv("SMS_GATEWAY_METHOD", "GET")
    sms_gateway_body = os.getenv("SMS_GATEWAY_BODY", "")
    sms_gateway_headers = os.getenv("SMS_GATEWAY_HEADERS", "")

    sms_provider = os.getenv("SMS_PROVIDER", "")
    sms_robita_base = os.getenv("SMS_ROBITA_BASE", "https://sms.robita.tj")
    sms_robita_login = os.getenv("SMS_ROBITA_LOGIN", "")
    sms_robita_password = os.getenv("SMS_ROBITA_PASSWORD", "")
    sms_robita_sender = os.getenv("SMS_ROBITA_SENDER", "0175")


settings = Settings()
