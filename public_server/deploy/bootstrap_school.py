"""Creates a school on the Public Server and prints its API key once.

The school server proves who it is with a shared key: it sends the raw key
in X-School-Key, and this server compares it against a hash. Only the hash
is ever stored, so the raw key exists exactly once -- in the output of this
script -- and has to go straight into the school server's PUBLIC_SERVER_API_KEY.

    python deploy/bootstrap_school.py "Maktabi intellektuali"
    python deploy/bootstrap_school.py "Maktabi intellektuali" --rotate

Without --rotate an existing school is left alone, because rotating the key
stops the school server syncing until its own .env is updated to match.
"""

import argparse
import secrets
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import app.main  # noqa: F401,E402 -- registers every model and builds the schema
from app.database import SessionLocal  # noqa: E402
from app.models.school_model import School  # noqa: E402
from app.utils.security import hash_school_key  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("name", help="School name")
    parser.add_argument(
        "--rotate",
        action="store_true",
        help="Issue a new key for a school that already exists",
    )
    args = parser.parse_args()

    db = SessionLocal()
    try:
        school = db.query(School).filter(School.name == args.name).first()

        if school and not args.rotate:
            print(f"'{args.name}' allaqachon mavjud (id={school.id}).")
            print("Yangi kalit kerak bo'lsa --rotate qo'shing.")
            print("DIQQAT: kalit almashtirilgach, maktab serverining .env i ham")
            print("yangilanmaguncha sinxronizatsiya to'xtaydi.")
            return 1

        raw_key = secrets.token_urlsafe(32)

        if school:
            school.api_key_hash = hash_school_key(raw_key)
            school.is_active = True
            action = "kalit almashtirildi"
        else:
            school = School(
                name=args.name,
                api_key_hash=hash_school_key(raw_key),
                is_active=True,
            )
            db.add(school)
            action = "maktab yaratildi"

        db.commit()
        db.refresh(school)

        print()
        print(f"  {action}: {school.name} (id={school.id})")
        print()
        print("  Maktab serverining .env fayliga yozing:")
        print(f"    PUBLIC_SERVER_API_KEY={raw_key}")
        print(f"    PUBLIC_SERVER_URL=https://SIZNING.DOMEN")
        print()
        print("  Bu kalit boshqa hech qachon ko'rsatilmaydi -- faqat xeshi saqlanadi.")
        print()
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
