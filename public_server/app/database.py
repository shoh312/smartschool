import os

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, declarative_base

load_dotenv()

DATABASE_URL = os.getenv(
    "DATABASE_URL", "postgresql://postgres:admin@localhost/smartschool_public"
)

engine = create_engine(DATABASE_URL)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def ensure_database_schema() -> None:
    """This server uses metadata.create_all instead of Alembic, same as the
    local backend -- create_all only creates missing tables, so a column
    added to an existing table's model needs this additive statement too.
    """
    statements = [
        "ALTER TABLE grades ADD COLUMN IF NOT EXISTS quarter INTEGER",
        "ALTER TABLE students ALTER COLUMN parent_id DROP NOT NULL",
        "ALTER TABLE device_tokens ADD COLUMN IF NOT EXISTS student_id INTEGER REFERENCES students(id)",
        "CREATE INDEX IF NOT EXISTS ix_device_tokens_student_id ON device_tokens (student_id)",
        "ALTER TABLE student_analytics ADD COLUMN IF NOT EXISTS class_average DOUBLE PRECISION",
        "ALTER TABLE student_analytics ADD COLUMN IF NOT EXISTS parallel_average DOUBLE PRECISION",
        "ALTER TABLE student_analytics ADD COLUMN IF NOT EXISTS school_average DOUBLE PRECISION",
        "ALTER TABLE student_analytics ADD COLUMN IF NOT EXISTS trend JSON DEFAULT '[]'",
        "ALTER TABLE student_analytics ADD COLUMN IF NOT EXISTS school_year INTEGER",
        # Widens the old (student_id, quarter) uniqueness to also include
        # school_year -- without it, a new school year's Q1 snapshot would
        # silently overwrite last year's Q1 row on upsert instead of
        # creating a separate one. Guarded because Postgres has no
        # "ADD CONSTRAINT IF NOT EXISTS".
        "ALTER TABLE student_analytics DROP CONSTRAINT IF EXISTS uq_student_analytics_student_quarter",
        """
        DO $$
        BEGIN
            ALTER TABLE student_analytics
                ADD CONSTRAINT uq_student_analytics_student_quarter_year UNIQUE (student_id, quarter, school_year);
        EXCEPTION WHEN duplicate_object OR duplicate_table THEN
            NULL;
        END $$;
        """,
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS username VARCHAR",
        "CREATE UNIQUE INDEX IF NOT EXISTS ix_students_username ON students (username)",
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS password_hash VARCHAR",
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS password_salt VARCHAR",
    ]
    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))
