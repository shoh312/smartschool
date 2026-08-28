import os

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, declarative_base

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:admin@localhost/smartschool")

# `idle_in_transaction_session_timeout` is the safety net, and it exists
# because the failure it prevents took the whole school offline twice.
#
# A session that opens a transaction and then stops talking -- a camera
# thread holding one open, or a killed process whose socket Postgres has not
# noticed yet -- blocks every later ALTER TABLE. The startup migrations are
# ALTERs, so the next server to start queues behind the dead session, and
# every request that touches those tables queues behind the migration. From
# the outside the app simply stops responding, with no error anywhere.
#
# Sixty seconds is far longer than any legitimate transaction here (the
# longest is a student registration with face extraction) and far shorter
# than a school day.
#
# pool_pre_ping because the Wi-Fi on this machine changes address regularly,
# which silently kills pooled connections; without it the first request after
# a network change fails instead of reconnecting.
# SQLAlchemy's default pool is five connections with ten of overflow, which
# is sized for a small web app and not for this one. Counted honestly, a
# quiet moment here already wants more than fifteen: six background loops
# each holding one while they sweep, a camera thread with a session open for
# as long as it runs, every open websocket, and then the ordinary requests --
# a phone polling live status, a director's app loading classes and students,
# a teacher saving a grade.
#
# Past the limit SQLAlchemy does not queue politely, it waits thirty seconds
# and then raises, and every one of those requests becomes a 500. That is
# what it looked like from the outside: adding a student from the phone
# failed, the class list failed, live status failed, all at once and with no
# obvious cause, while the database itself sat almost idle.
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    pool_size=20,
    max_overflow=30,
    # Fail loudly instead of hanging half a minute first. If the pool is ever
    # genuinely exhausted again, a request that gives up in five seconds is a
    # bug report; one that gives up in thirty is an outage.
    pool_timeout=5,
    # Connections are recycled every half hour so a long-lived one never
    # outlives what the network or Postgres is willing to keep open.
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
        # Phone numbers used to be stored as typed ("+992...", "992...", with
        # spaces/dashes), so the same parent could end up split across two
        # rows depending on formatting. Normalize to digits-only so parent
        # login/lookup by phone matches regardless of how it was entered.
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
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS username VARCHAR",
        # Postgres unique indexes already allow any number of NULLs (NULL is
        # never considered equal to another NULL), so a plain unique index
        # here still permits every student without login credentials.
        "CREATE UNIQUE INDEX IF NOT EXISTS ix_students_username ON students (username)",
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS password_hash VARCHAR",
        "ALTER TABLE students ADD COLUMN IF NOT EXISTS password_salt VARCHAR",
        "ALTER TABLE parents ADD COLUMN IF NOT EXISTS password_hash VARCHAR",
        "ALTER TABLE parents ADD COLUMN IF NOT EXISTS password_salt VARCHAR",
        "ALTER TABLE schools ADD COLUMN IF NOT EXISTS live_video_enabled BOOLEAN NOT NULL DEFAULT TRUE",
        "ALTER TABLE schools ADD COLUMN IF NOT EXISTS group_mode BOOLEAN NOT NULL DEFAULT FALSE",
        # The two ALTERs above only fire on a database that predates these
        # columns. On a brand new one create_all builds the table first, and
        # it wrote NOT NULL with no default at all -- so the very next thing
        # startup does, inserting its own "Default School" row with a plain
        # INSERT, failed and took the whole server down before it had served
        # a single request. Setting the default explicitly repairs a table
        # already created that way; the model now carries a server_default so
        # freshly created ones never need repairing.
        "ALTER TABLE schools ALTER COLUMN live_video_enabled SET DEFAULT TRUE",
        "ALTER TABLE schools ALTER COLUMN group_mode SET DEFAULT FALSE",
        # One camera, several groups through the day -- see CameraPosition.
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
    ]

    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))


def ensure_default_school_and_backfill() -> int:
    """Multi-tenant migration: every row used to implicitly belong to one school.

    Creates a "Default School" (if none exists yet) and assigns it to any
    class/student/parent/camera row that predates the school_id column, so
    existing single-school deployments keep working unchanged.
    """
    with engine.begin() as connection:
        school_id = connection.execute(
            text("SELECT id FROM schools ORDER BY id ASC LIMIT 1")
        ).scalar()

        if school_id is None:
            # Every NOT NULL column named explicitly, rather than trusting the
            # table to have defaults.
            #
            # It twice did not. `default=` on the model is applied by the ORM
            # and this INSERT is raw SQL; the migration's `ADD COLUMN ...
            # DEFAULT` only fires on a database that predates the column, and
            # a brand new one has it built by create_all instead. Both
            # safeguards were real and both missed this line, so the first
            # startup of a fresh install died inserting its own seed row.
            #
            # Spelling the values out here does not depend on either.
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
    """Grades entered before the `quarter` column existed have it NULL --
    derive it from grade_date using the same month mapping as
    app.utils.academic_calendar.quarter_for_date, so historical grades are
    included in quarterly rankings instead of silently excluded.
    """
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
    """Same idea as ensure_grade_quarter_backfill, for the school_year
    column added alongside it later -- derives the year a grade's school
    year STARTS in (see academic_calendar.school_year_for_date: Sep-Dec
    belongs to the same calendar year, Jan-Aug belongs to the previous one).
    """
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
    """Migrate data from old Room/RoomPosition model to Class fields and
    Camera.class_id. Copies room_position data into class columns and sets
    camera.class_id from the active room_position's class_id.
    """
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
