import os
from datetime import time

from dotenv import load_dotenv

load_dotenv()


class Settings:
    attendance_late_after = time(8, 15)
    left_school_after_minutes = int(os.getenv("LEFT_SCHOOL_AFTER_MINUTES", "30"))
    firebase_credentials = os.getenv("FIREBASE_CREDENTIALS")
    auth_secret = os.getenv("SMARTSCHOOL_AUTH_SECRET", "change-this-secret")
    jwt_secret = os.getenv(
        "JWT_SECRET",
        os.getenv(
            "SMARTSCHOOL_JWT_SECRET",
            "change-this-development-jwt-secret-before-production",
        ),
    )
    jwt_algorithm = os.getenv("JWT_ALGORITHM", "HS256")
    jwt_access_token_minutes = int(os.getenv("JWT_ACCESS_TOKEN_MINUTES", "1440"))
    public_server_url = os.getenv("PUBLIC_SERVER_URL", "http://localhost:8200")
    public_server_api_key = os.getenv("PUBLIC_SERVER_API_KEY", "")
    gemini_api_key = os.getenv("GEMINI_API_KEY", "")

    # The welcome SMS is sent from here rather than from the Public Server
    # because the pupil's password exists in plaintext only on this machine,
    # for the moment the director types it -- see credentials_service.
    sms_provider = os.getenv("SMS_PROVIDER", "")
    sms_robita_base = os.getenv("SMS_ROBITA_BASE", "https://sms.robita.tj")
    sms_robita_login = os.getenv("SMS_ROBITA_LOGIN", "")
    sms_robita_password = os.getenv("SMS_ROBITA_PASSWORD", "")
    sms_robita_sender = os.getenv("SMS_ROBITA_SENDER", "0175")


settings = Settings()
