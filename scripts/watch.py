# -*- coding: utf-8 -*-
"""Watches one class's camera work, live, in the terminal.

There is no way to see what the recognition is doing while it happens. The
app shows the result afterwards and the server's own output goes to a log
file nobody has open. On the day of a pilot the question is the immediate
one -- is the camera about to look, did it just look, and who did it find --
and that is what this answers.

    cd backend
    venv\\Scripts\\python.exe ..\\scripts\\watch.py

Pick a class from the list and leave it running. Ctrl+C to stop.
"""

import argparse
import os
import sys
import time
from datetime import date, datetime

import urllib.error
import urllib.request
import json

BASE = os.environ.get("SMARTSCHOOL_URL", "http://localhost:8000")
EMAIL = os.environ.get("SMARTSCHOOL_EMAIL", "director@smartschool.com")
PASSWORD = os.environ.get("SMARTSCHOOL_PASSWORD", "1234")

REFRESH_SECONDS = 1.0

# Windows terminals only understand these once someone has enabled virtual
# terminal processing, which python does on import of colorama or by this
# call; without it the codes print as garbage.
if os.name == "nt":
    os.system("")

RESET = "\033[0m"
DIM = "\033[2m"
BOLD = "\033[1m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
RED = "\033[91m"
CYAN = "\033[96m"


def call(path, token=None, body=None, method="GET"):
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(BASE + path, data=data, method=method)
    request.add_header("Content-Type", "application/json")
    if token:
        request.add_header("Authorization", "Bearer " + token)
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.loads(response.read().decode())


def login():
    try:
        return call("/auth/director/login",
                    body={"email": EMAIL, "password": PASSWORD},
                    method="POST")["access_token"]
    except urllib.error.URLError as err:
        print("%sServerga ulanib bo'lmadi (%s)%s" % (RED, BASE, RESET))
        print("  %s" % err)
        print("  start.bat ishga tushganmi?")
        raise SystemExit(1)


def pick_class(token):
    classes = sorted(call("/classes", token), key=lambda c: c["name"])
    if not classes:
        print("Sinf topilmadi.")
        raise SystemExit(1)

    print()
    print("%sSINFLAR%s" % (BOLD, RESET))
    for index, item in enumerate(classes, 1):
        window = item.get("start_time") or "-"
        print("  %2d) %-10s  boshlanish: %s" % (index, item["name"], window))
    print()

    while True:
        choice = input("Qaysi sinf? (raqam, chiqish uchun q): ").strip()
        if choice.lower() in ("q", "quit", "exit"):
            raise SystemExit(0)
        if choice.isdigit() and 1 <= int(choice) <= len(classes):
            return classes[int(choice) - 1]
        print("  Raqamni to'g'ri kiriting.")


def window_end(school_class):
    """Mirrors the server's own arithmetic: start plus today's durations."""
    start = school_class.get("start_time")
    timetable = school_class.get("timetable") or {}
    if not start:
        return None
    day_key = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"][datetime.now().weekday()]
    entries = timetable.get(day_key) or []
    total = 0
    for entry in entries:
        try:
            total += int(entry.get("duration_minutes") or 45)
        except (TypeError, ValueError, AttributeError):
            total += 45
    if total <= 0:
        return school_class.get("end_time")
    try:
        hours, minutes = map(int, start.split(":"))
    except (ValueError, AttributeError):
        return school_class.get("end_time")
    end_minutes = hours * 60 + minutes + total
    return "%02d:%02d" % (end_minutes // 60 % 24, end_minutes % 60)


def fetch_status(token, class_id):
    try:
        rows = call("/cameras/status", token)
    except Exception:
        return None
    for row in rows:
        # Match on the camera's own room, not on whichever class happens to
        # be in session: outside lesson hours the latter is null, and this
        # would report a perfectly healthy camera as missing.
        if row.get("camera_class_id") == class_id or row.get("class_id") == class_id:
            return row
    return None


def fetch_today(token, class_id):
    """Who has been seen today, newest first."""
    try:
        rows = call("/attendance/class-analytics/%d?days=1" % class_id, token)
    except Exception:
        return []
    seen = []
    for row in rows:
        status = row.get("today_status")
        if status in ("present", "late", "left_school"):
            seen.append((row["first_name"], row["last_name"], status))
    return seen


def status_line(status):
    if status is None:
        return "%s● bu sinfga kamera biriktirilmagan%s" % (RED, RESET)

    phase = status.get("phase") or "?"
    if status.get("detecting"):
        seconds = status.get("detecting_for")
        extra = " (%ds)" % seconds if seconds is not None else ""
        return "%s● QIDIRILMOQDA%s%s" % (GREEN, extra, RESET)

    remaining = status.get("seconds_to_detect")
    if remaining is None:
        return "%s● %s%s" % (DIM, phase, RESET)

    if remaining >= 60:
        left = "%d daq %02d son" % (remaining // 60, remaining % 60)
    else:
        left = "%d soniya" % remaining
    return "%s● keyingi qidiruvgacha: %s%s" % (YELLOW, left, RESET)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--class-id", type=int, help="Sinfni so'ramasdan tanlash")
    args = parser.parse_args()

    token = login()

    if args.class_id:
        classes = call("/classes", token)
        school_class = next((c for c in classes if c["id"] == args.class_id), None)
        if school_class is None:
            print("Sinf topilmadi: %d" % args.class_id)
            raise SystemExit(1)
    else:
        school_class = pick_class(token)

    class_id = school_class["id"]
    start = school_class.get("start_time")
    end = window_end(school_class)

    # A missing end is not a formatting gap, it is the answer: today has no
    # lessons in this class's timetable, so the camera will never open. Said
    # plainly here, because otherwise the countdown simply never appears and
    # there is nothing on screen explaining why.
    if end:
        schedule = "dars: %s -> %s" % (start or "?", end)
    else:
        day_names = ["dushanba", "seshanba", "chorshanba", "payshanba",
                     "juma", "shanba", "yakshanba"]
        schedule = ("bugun (%s) uchun dars jadvali yo'q — kamera ishlamaydi"
                    % day_names[datetime.now().weekday()])

    known = set()
    last_refresh = 0.0
    today_seen = []

    print()
    print("%s%s — jonli kuzatuv%s   (to'xtatish: Ctrl+C)" % (BOLD, school_class["name"], RESET))
    print("%s%s%s" % (DIM, schedule, RESET))
    print()

    try:
        while True:
            status = fetch_status(token, class_id)

            # The roster query is heavier than the status one and nothing in
            # it can change faster than a detect window, so it runs on its
            # own slower clock.
            if time.time() - last_refresh > 5:
                today_seen = fetch_today(token, class_id)
                last_refresh = time.time()

                for first, last, state in today_seen:
                    key = (first, last)
                    if key in known:
                        continue
                    known.add(key)
                    colour = GREEN if state == "present" else YELLOW
                    label = {"present": "keldi", "late": "kechikdi",
                             "left_school": "chiqib ketdi"}.get(state, state)
                    print("  %s%s  %s %s — %s%s" % (
                        colour, datetime.now().strftime("%H:%M:%S"),
                        first, last, label, RESET))

            roster = status.get("roster") if status else None
            counted = "%d ta yuz" % roster if roster is not None else "-"

            sys.stdout.write("\r\033[K%s   %s%s topilgan: %d   ro'yxatda: %s%s" % (
                status_line(status), DIM,
                datetime.now().strftime("%H:%M:%S "),
                len(known), counted, RESET))
            sys.stdout.flush()

            time.sleep(REFRESH_SECONDS)
    except KeyboardInterrupt:
        print()
        print()
        print("Kuzatuv to'xtatildi. Bugun topilganlar: %d" % len(known))


if __name__ == "__main__":
    main()
