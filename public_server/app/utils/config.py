import os

from dotenv import load_dotenv

load_dotenv()


class Settings:
    auth_secret = os.getenv("SMARTSCHOOL_PUBLIC_AUTH_SECRET", "change-this-secret")
    firebase_credentials = os.getenv("FIREBASE_CREDENTIALS")

    # See sms_service for the shape of these. Empty URL means "log the code
    # instead of sending it", which is how the server runs until the school
    # has a gateway contract.
    sms_gateway_url = os.getenv("SMS_GATEWAY_URL", "")
    sms_gateway_method = os.getenv("SMS_GATEWAY_METHOD", "GET")
    sms_gateway_body = os.getenv("SMS_GATEWAY_BODY", "")
    sms_gateway_headers = os.getenv("SMS_GATEWAY_HEADERS", "")

    # "robita" drives the sms.robita.tj web panel (that provider has no API);
    # anything else falls back to the generic gateway above, and with neither
    # configured the message is written to the outbox file and not sent.
    sms_provider = os.getenv("SMS_PROVIDER", "")
    sms_robita_base = os.getenv("SMS_ROBITA_BASE", "https://sms.robita.tj")
    sms_robita_login = os.getenv("SMS_ROBITA_LOGIN", "")
    sms_robita_password = os.getenv("SMS_ROBITA_PASSWORD", "")
    # The account's registered sender id, taken from the panel's own dropdown.
    sms_robita_sender = os.getenv("SMS_ROBITA_SENDER", "0175")


settings = Settings()
