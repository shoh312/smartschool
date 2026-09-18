import os

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, declarative_base

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:admin@localhost/smartschool")

engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    pool_size=20,
    max_overflow=30,
    pool_timeout=5,
    pool_recycle=1800,
    connect_args={"options": "-c idle_in_transaction_session_timeout=60000"},
)

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
        "ALTER TABLE classes ADD COLUMN IF NOT EXISTS school_id INTEGER REFERENCES schools(id)",
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS school_id INTEGER REFERENCES schools(id)",
        "ALTER TABLE parents ADD COLUMN IF NOT EXISTS school_id INTEGER REFERENCES schools(id)",
        "ALTER TABLE cameras ADD COLUMN IF NOT EXISTS school_id INTEGER REFERENCES schools(id)",
        "ALTER TABLE directors ADD COLUMN IF NOT EXISTS is_superadmin BOOLEAN NOT NULL DEFAULT false",
        "ALTER TABLE directors ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT false",
        "ALTER TABLE schools ADD COLUMN IF NOT EXISTS phone VARCHAR",
        "ALTER TABLE schools ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true",
        "ALTER TABLE teachers ADD COLUMN IF NOT EXISTS subject VARCHAR",
        "CREATE INDEX IF NOT EXISTS ix_teachers_subject ON teachers (subject)",
        "UPDATE parents SET phone = regexp_replace(phone, '[^0-9]', '', 'g') WHERE phone IS NOT NULL",
        "CREATE INDEX IF NOT EXISTS ix_classes_school_id ON classes (school_id)",
        "CREATE INDEX IF NOT EXISTS ix_students_school_id ON students (school_id)",
        "CREATE INDEX IF NOT EXISTS ix_parents_school_id ON parents (school_id)",
        "CREATE INDEX IF NOT EXISTS ix_cameras_school_id ON cameras (school_id)",
        "CREATE INDEX IF NOT EXISTS ix_grades_student_id ON grades (student_id)",
        "CREATE INDEX IF NOT EXISTS ix_grades_class_id ON grades (class_id)",
        "CREATE INDEX IF NOT EXISTS ix_teacher_classes_teacher_id ON teacher_classes (teacher_id)",
        "CREATE INDEX IF NOT EXISTS ix_teacher_classes_class_id ON teacher_classes (class_id)",
        "ALTER TABLE cameras ADD COLUMN IF NOT EXISTS class_id INTEGER REFERENCES classes(id)",
        "CREATE INDEX IF NOT EXISTS ix_cameras_class_id ON cameras (class_id)",
        "ALTER TABLE classes ADD COLUMN IF NOT EXISTS start_time VARCHAR",
        "ALTER TABLE classes ADD COLUMN IF NOT EXISTS end_time VARCHAR",
        "ALTER TABLE classes ADD COLUMN IF NOT EXISTS detect_duration_seconds INTEGER",
        "ALTER TABLE classes ADD COLUMN IF NOT EXISTS wait_duration_minutes INTEGER",
        "ALTER TABLE classes ADD COLUMN IF NOT EXISTS timetable JSON",
        "ALTER TABLE grades ADD COLUMN IF NOT EXISTS quarter INTEGER",
        "CREATE INDEX IF NOT EXISTS ix_grades_quarter ON grades (quarter)",
        "ALTER TABLE grades ADD COLUMN IF NOT EXISTS school_year INTEGER",
        "CREATE INDEX IF NOT EXISTS ix_grades_school_year ON grades (school_year)",
        "ALTER TABLE lessons ADD COLUMN IF NOT EXISTS teacher_id INTEGER REFERENCES teachers(id)",
        "ALTER TABLE lessons ADD COLUMN IF NOT EXISTS room VARCHAR",
        "ALTER TABLE lesson_attendance ADD COLUMN IF NOT EXISTS confidence DOUBLE PRECISION",
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS username VARCHAR",
        "CREATE UNIQUE INDEX IF NOT EXISTS ix_students_username ON students (username)",
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS password_hash VARCHAR",
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS password_salt VARCHAR",
        "ALTER TABLE parents ADD COLUMN IF NOT EXISTS password_hash VARCHAR",
        "ALTER TABLE parents ADD COLUMN IF NOT EXISTS password_salt VARCHAR",
        "ALTER TABLE schools ADD COLUMN IF NOT EXISTS live_video_enabled BOOLEAN NOT NULL DEFAULT TRUE",
        "ALTER TABLE schools ADD COLUMN IF NOT EXISTS group_mode BOOLEAN NOT NULL DEFAULT FALSE",
        "ALTER TABLE schools ALTER COLUMN live_video_enabled SET DEFAULT TRUE",
        "ALTER TABLE schools ALTER COLUMN group_mode SET DEFAULT FALSE",
        """
        CREATE TABLE IF NOT EXISTS camera_positions (
            id SERIAL PRIMARY KEY,
            camera_id INTEGER NOT NULL REFERENCES cameras(id) ON DELETE CASCADE,
            class_id INTEGER NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
            day_of_week INTEGER,
            start_time VARCHAR NOT NULL,
            end_time VARCHAR NOT NULL,
            created_at TIMESTAMP DEFAULT now()
        )
        """,
        "CREATE INDEX IF NOT EXISTS ix_camera_positions_camera_id ON camera_positions (camera_id)",
        "ALTER TABLE camera_positions ADD COLUMN IF NOT EXISTS subject VARCHAR",
        "ALTER TABLE lessons ADD COLUMN IF NOT EXISTS position_id INTEGER REFERENCES camera_positions(id) ON DELETE CASCADE",
        "CREATE INDEX IF NOT EXISTS ix_lessons_position_id ON lessons (position_id)",
        "ALTER TABLE schools ADD COLUMN IF NOT EXISTS sms_enabled BOOLEAN NOT NULL DEFAULT TRUE",
        "ALTER TABLE schools ALTER COLUMN sms_enabled SET DEFAULT TRUE",
        "ALTER TABLE schools ADD COLUMN IF NOT EXISTS attendance_notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE",
    ]

    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))


def ensure_default_school_and_backfill() -> int:
    with engine.begin() as connection:
        school_id = connection.execute(
            text("SELECT id FROM schools ORDER BY id ASC LIMIT 1")
        ).scalar()

        if school_id is None:
            school_id = connection.execute(
                text(
                    "INSERT INTO schools (name, is_active, live_video_enabled, group_mode) "
                    "VALUES ('Default School', true, true, false) RETURNING id"
                )
            ).scalar()

        for table in ("classes", "students", "parents", "cameras"):
            connection.execute(
                text(f"UPDATE {table} SET school_id = :school_id WHERE school_id IS NULL"),
                {"school_id": school_id},
            )

        return school_id


def ensure_grade_quarter_backfill() -> None:
    with engine.begin() as connection:
        connection.execute(
            text(
                """
                UPDATE grades SET quarter = CASE
                    WHEN EXTRACT(MONTH FROM grade_date) IN (9, 10) THEN 1
                    WHEN EXTRACT(MONTH FROM grade_date) IN (11, 12) THEN 2
                    WHEN EXTRACT(MONTH FROM grade_date) IN (1, 2, 3) THEN 3
                    ELSE 4
                END
                WHERE quarter IS NULL
                """
            )
        )


def ensure_grade_school_year_backfill() -> None:
    with engine.begin() as connection:
        connection.execute(
            text(
                """
                UPDATE grades SET school_year = CASE
                    WHEN EXTRACT(MONTH FROM grade_date) >= 9 THEN EXTRACT(YEAR FROM grade_date)
                    ELSE EXTRACT(YEAR FROM grade_date) - 1
                END
                WHERE school_year IS NULL
                """
            )
        )


def ensure_rooms_backfill() -> None:
    with engine.begin() as connection:
        legacy_tables_exist = connection.execute(
            text(
                "SELECT to_regclass('public.room_positions') IS NOT NULL "
                "AND to_regclass('public.rooms') IS NOT NULL"
            )
        ).scalar()
        if not legacy_tables_exist:
            return

    with engine.begin() as connection:
        connection.execute(
            text(
                "UPDATE classes c "
                "SET start_time = rp.start_time, "
                "    end_time = rp.end_time, "
                "    detect_duration_seconds = rp.detect_duration_seconds, "
                "    wait_duration_minutes = rp.wait_duration_minutes "
                "FROM room_positions rp "
                "JOIN rooms r ON r.id = rp.room_id "
                "WHERE rp.class_id = c.id AND c.position IS NULL"
            )
        )
        connection.execute(
            text(
                "UPDATE cameras cam "
                "SET class_id = rp.class_id "
                "FROM rooms r "
                "JOIN room_positions rp ON rp.room_id = r.id "
                "WHERE cam.room_id = r.id AND cam.class_id IS NULL"
            )
        )
