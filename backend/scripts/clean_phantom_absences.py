# -*- coding: utf-8 -*-
"""Removes absences recorded on days the class had no lessons.

Until the timetable check landed in `mark_absent_students`, the day-level
job marked every active pupil absent every day after the morning cutoff --
weekends, holidays, and classes whose timetable had never been entered. Those
rows are not history; they are a bug's output, and they distort the parent's
month calendar, the attendance rate in analytics, and every badge computed
from it.

Judged against the *current* timetable, since that is the only schedule the
database keeps -- so a class that used to have Saturday lessons and no longer
does would have its old Saturdays cleared too. Worth knowing before running
it; harmless for a school whose week has not moved.

Deletions are pushed to the Public Server through the same outbox every other
change uses, so a parent's phone stops showing them as well.

    python scripts/clean_phantom_absences.py           # dry run, changes nothing
    python scripts/clean_phantom_absences.py --apply   # actually deletes
"""

import collections
import datetime
import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import app.models  # noqa: E402,F401  every mapper must be registered first
from app.database import SessionLocal  # noqa: E402
from app.models.attendance_model import Attendance  # noqa: E402
from app.models.lesson_model import Lesson  # noqa: E402
from app.models.student import Student  # noqa: E402
from app.services.attendance_service import ABSENT, classes_in_session_on  # noqa: E402
from app.services.sync_outbox_service import enqueue_attendance_event  # noqa: E402

WEEKDAYS = ["Dushanba", "Seshanba", "Chorshanba", "Panjshanba", "Juma", "Shanba", "Yakshanba"]


def phantom_absences(db, keep_weekdays=()):
    """Absence rows whose class had nothing scheduled that weekday.

    `keep_weekdays` protects a day the timetable does not know about yet.
    This school runs Saturday lessons for grades 5-11 but has never entered
    them, so by the timetable every Saturday looks like a holiday -- while
    the real problem there is the opposite: no timetable means the cameras
    never start, so nobody can be seen and everybody is marked absent. Those
    rows are wrong too, but deleting them is the school's call, not this
    script's guess.
    """
    lessons = db.query(Lesson).all()
    in_session = {day: classes_in_session_on(lessons, day) for day in range(7)}

    rows = (
        db.query(Attendance, Student)
        .join(Student, Student.id == Attendance.student_id)
        .filter(Attendance.status == ABSENT)
        .all()
    )
    return [
        attendance
        for attendance, student in rows
        if attendance.attendance_date.weekday() not in keep_weekdays
        and student.class_id not in in_session[attendance.attendance_date.weekday()]
    ]


def _keep_weekdays(argv):
    """--keep 5 6  -> leave Saturday and Sunday rows alone."""
    if "--keep" not in argv:
        return ()
    days = []
    for value in argv[argv.index("--keep") + 1:]:
        if not value.isdigit():
            break
        days.append(int(value))
    return tuple(days)


def main():
    apply_changes = "--apply" in sys.argv
    keep = _keep_weekdays(sys.argv)
    if keep:
        print("Tegilmaydigan kunlar: %s\n" % ", ".join(WEEKDAYS[d] for d in keep))
    db = SessionLocal()
    try:
        doomed = phantom_absences(db, keep_weekdays=keep)
        total = db.query(Attendance).filter(Attendance.status == ABSENT).count()

        by_weekday = collections.Counter(a.attendance_date.weekday() for a in doomed)
        print("Jami 'kelmadi' yozuvlari : %d" % total)
        print("Darssiz kunga yozilgani  : %d" % len(doomed))
        for day in range(7):
            if by_weekday[day]:
                print("   %-11s %d" % (WEEKDAYS[day], by_weekday[day]))

        if not doomed:
            print("\nTozalash shart emas.")
            return
        if not apply_changes:
            print("\nSinov rejimi -- hech narsa o'chirilmadi. O'chirish uchun: --apply")
            return

        # Written before anything is removed: these rows are a bug's output,
        # but they are still the only record of what the school believed on
        # those days, and this script is not reversible without them.
        backup = os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            "phantom_absences_%s.json" % datetime.datetime.now().strftime("%Y%m%d_%H%M%S"),
        )
        with io.open(backup, "w", encoding="utf-8") as handle:
            json.dump(
                [
                    {
                        "id": a.id,
                        "student_id": a.student_id,
                        "attendance_date": a.attendance_date.isoformat(),
                        "status": a.status,
                        "detected_at": a.detected_at.isoformat() if a.detected_at else None,
                    }
                    for a in doomed
                ],
                handle,
                ensure_ascii=False,
                indent=2,
            )
        print("\nZaxira nusxa: %s" % backup)

        for attendance in doomed:
            # Before the delete: the payload needs the row it describes.
            enqueue_attendance_event(db, attendance, operation="delete")
            db.delete(attendance)
        db.commit()
        print("\n%d ta yozuv o'chirildi va public serverga o'chirish navbatga qo'yildi." % len(doomed))
    finally:
        db.close()


if __name__ == "__main__":
    main()
