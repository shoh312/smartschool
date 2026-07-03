import os

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, declarative_base

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:admin@localhost/smartschool")

engine = create_engine(DATABASE_URL)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def ensure_database_schema():
    """Small compatibility migration for existing local deployments.

    The project currently uses metadata.create_all instead of Alembic. These
    additive statements keep older databases working when new backend features
    add columns or indexes.
    """
    statements = [
        "ALTER TABLE attendance ADD COLUMN IF NOT EXISTS last_seen TIMESTAMP",
        "ALTER TABLE attendance ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT now()",
        "ALTER TABLE attendance ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT now()",
        "CREATE INDEX IF NOT EXISTS ix_attendance_student_date ON attendance (student_id, attendance_date)",
        "ALTER TABLE parents ADD COLUMN IF NOT EXISTS firebase_token VARCHAR",
        "CREATE INDEX IF NOT EXISTS ix_parents_phone ON parents (phone)",
        "CREATE INDEX IF NOT EXISTS ix_classes_name ON classes (name)",
        "ALTER TABLE cameras ADD COLUMN IF NOT EXISTS detection_start_time VARCHAR",
        "ALTER TABLE cameras ADD COLUMN IF NOT EXISTS detection_end_time VARCHAR",
        "ALTER TABLE cameras ADD COLUMN IF NOT EXISTS detect_duration_seconds INTEGER",
        "ALTER TABLE cameras ADD COLUMN IF NOT EXISTS wait_duration_minutes INTEGER",
    ]

    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))
