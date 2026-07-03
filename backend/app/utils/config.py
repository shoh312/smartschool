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


settings = Settings()
