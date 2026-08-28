# -*- coding: utf-8 -*-
"""Live view of one camera, in a terminal.

    python scripts/room.py "Room 3"
    python scripts/room.py 7            (by camera id)

Prints a line whenever something changes -- the group in front of the camera,
a detect window opening or closing, somebody recognised -- and keeps a
countdown to the next window on the last line in between. Nothing else: a
scrolling uvicorn log tells you the server is alive, this tells you what the
camera is doing.

Reads the running server's own view of the loop (GET /cameras/status) rather
than guessing from the database, because on a morning when nobody has walked
in yet those are the same empty table and completely different situations: a
camera counting down, and a camera that never started.
"""

import datetime
import json
import os
import sys
import time
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + os.sep + "backend")

import app.models  # noqa: E402,F401  registers every mapper
from app.database import SessionLocal  # noqa: E402
from app.models.attendance_model import Attendance  # noqa: E402
from app.models.camera_model import Camera  # noqa: E402
from app.models.class_model import Class  # noqa: E402
from app.models.director_model import Director  # noqa: E402
from app.models.student import Student  # noqa: E402
from app.utils.security import create_jwt_access_token  # noqa: E402

SERVER = os.getenv("SMARTFLOW_SERVER", "http://127.0.0.1:8000")
POLL_SECONDS = 2


def safe(text):
    """This console is cp1251 and a Tajik name printed straight out kills the
    script mid-run -- see the note in the project's memory."""
    encoding = sys.stdout.encoding or "utf-8"
    return str(text or "").encode(encoding, "replace").decode(encoding, "replace")


def clock():
    return datetime.datetime.now().strftime("%H:%M:%S")


def say(line):
    # \r + spaces first: the countdown owns the current line, and printing
    # over it without clearing leaves its tail behind.
    print("\r" + " " * 78 + "\r" + line, flush=True)


def find_camera(db, wanted):
    if wanted.isdigit():
        return db.query(Camera).filter(Camera.id == int(wanted)).first()
    return db.query(Camera).filter(Camera.name.ilike(wanted)).first()


def main():
    wanted = sys.argv[1] if len(sys.argv) > 1 else "Room 3"

    db = SessionLocal()
    camera = find_camera(db, wanted)
    if camera is None:
        print("Kamera topilmadi: %s" % safe(wanted))
        print("Mavjudlari: %s" % ", ".join(safe(c.name) for c in db.query(Camera).all()))
        return

    director = db.query(Director).filter(
        Director.school_id == camera.school_id,
        Director.is_active == True,  # noqa: E712
    ).first()
    if director is None:
        print("Bu maktabning direktori topilmadi")
        return
    token = create_jwt_access_token(
        str(director.id), {"role": "director", "school_id": director.school_id}
    )

    classes = {c.id: c.name for c in db.query(Class).all()}

    def student_name(student_id):
        """Looked up when needed, not cached at startup: a pupil registered
        while this window is open would otherwise show as a bare id."""
        try:
            student = db.query(Student).filter(Student.id == student_id).first()
        except Exception:  # noqa: BLE001 -- see the guard in the main loop
            db.rollback()
            return str(student_id)
        if student is None:
            return str(student_id)
        return ("%s %s" % (student.first_name, student.last_name)).strip()

    print("=" * 60)
    print("  %s   (kamera id=%s)" % (safe(camera.name), camera.id))
    print("  server: %s" % SERVER)
    print("  chiqish uchun Ctrl+C")
    print("=" * 60)

    last_phase = None
    last_group = None
    was_detecting = None
    was_roll_call = False
    seen_rows = set()

    # Anything already recorded today is history, not news.
    for row in db.query(Attendance).filter(
        Attendance.attendance_date == datetime.date.today()
    ).all():
        seen_rows.add(row.id)

    while True:
        try:
            request = urllib.request.Request(
                SERVER + "/cameras/status", headers={"Authorization": "Bearer " + token}
            )
            with urllib.request.urlopen(request, timeout=30) as response:
                rows = json.loads(response.read())
        except Exception as exc:  # noqa: BLE001 -- a restarting server is normal
            say("%s  server javob bermadi (%s)" % (clock(), type(exc).__name__))
            time.sleep(POLL_SECONDS)
            continue

        status = next((r for r in rows if r.get("camera_id") == camera.id), None)
        if status is None:
            say("%s  kamera hali ishga tushmagan" % clock())
            time.sleep(POLL_SECONDS)
            continue

        group = classes.get(status.get("class_id"))
        if group != last_group:
            if group:
                roster = db.query(Student).filter(
                    Student.class_id == status.get("class_id"),
                    Student.is_active == True,  # noqa: E712
                    Student.face_encoding.isnot(None),
                ).count()
                say("%s  GURUH: %s  (%s ta yuz yuklandi)" % (clock(), safe(group), roster))
            else:
                say("%s  xona bo'sh -- kamera kutmoqda" % clock())
            last_group = group

        phase = status.get("phase")
        if phase != last_phase:
            say("%s  bosqich: %s" % (clock(), safe(phase)))
            last_phase = phase

        # The roll call is its own thing, not just a long detect window: the
        # first ten minutes of a lesson, scanned every ten seconds, ending in
        # the one verdict that decides who came. Saying "detekt boshlandi" for
        # it would hide the only moment of the lesson that actually matters.
        roll_call = bool(status.get("roll_call"))
        if roll_call and not was_roll_call:
            say("%s  === RO'YXAT OCHILDI (10 daqiqa) ===" % clock())
        elif was_roll_call and not roll_call:
            say("%s  === RO'YXAT YOPILDI -- hukm chiqarildi ===" % clock())
        was_roll_call = roll_call

        detecting = bool(status.get("detecting"))
        if was_detecting is None:
            was_detecting = detecting
        elif detecting != was_detecting and not roll_call:
            say("%s  %s" % (clock(), "DETEKT BOSHLANDI" if detecting else "detekt tugadi"))
            was_detecting = detecting
        else:
            was_detecting = detecting

        # New attendance since the last pass -- the point of the whole thing.
        #
        # Guarded, because this window is meant to be left open all day and
        # the server it watches gets restarted underneath it. A dropped
        # connection used to raise straight out of the loop and kill the
        # monitor, so the one time you looked back at it, it was gone.
        try:
            db.expire_all()
            rows_today = db.query(Attendance).filter(
                Attendance.attendance_date == datetime.date.today()
            ).all()
        except Exception as exc:  # noqa: BLE001 -- a restarting database is normal
            db.rollback()
            say("%s  bazaga ulanmadi (%s)" % (clock(), type(exc).__name__))
            time.sleep(POLL_SECONDS)
            continue

        for row in rows_today:
            if row.id in seen_rows:
                continue
            seen_rows.add(row.id)
            mark = {
                "present": ">>> KELDI",
                "late": ">>> KECH KELDI",
                "absent": "    yo'q deb belgilandi",
            }.get(row.status, "    " + str(row.status))
            say("%s  %s: %s -> %s%s" % (
                clock(), mark, safe(student_name(row.student_id)), row.status,
                ("  (ishonch %.2f)" % row.confidence) if row.confidence else "",
            ))

        if roll_call:
            left = status.get("seconds_to_roll_call_close")
            line = "  RO'YXAT: %s/%s topildi | yopilishiga %s" % (
                status.get("seen", 0), status.get("roster", 0),
                _mmss(left) if left is not None else "?",
            )
        elif detecting:
            line = "  ... tanimoqda (%s soniya)" % (status.get("detecting_for") or 0)
        else:
            left = status.get("seconds_to_detect")
            line = ("  keyingi detekt: %s" % _mmss(left)) if left is not None else "  kutmoqda"
        print("\r" + line.ljust(78), end="", flush=True)

        time.sleep(POLL_SECONDS)


def _mmss(seconds):
    seconds = int(seconds)
    return "%d:%02d" % (seconds // 60, seconds % 60)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nto'xtatildi")
