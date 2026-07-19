import os

from dotenv import load_dotenv

load_dotenv()


class Settings:
    auth_secret = os.getenv("SMARTSCHOOL_PUBLIC_AUTH_SECRET", "change-this-secret")
    firebase_credentials = os.getenv("FIREBASE_CREDENTIALS")


settings = Settings()
