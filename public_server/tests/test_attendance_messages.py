"""What a parent actually receives when their child is detected.

This is the one message the product sends to somebody who never opens the
admin side, so it has to be right in two ways: in Tajik, like the rest of
their app, and specific about when. "Your child came to school" leaves the
question the parent had; "came at 08:12" answers it.

The clock is printed exactly as the school server wrote it -- no timezone
conversion anywhere in the path -- so a message must never shift the hour.
"""

from datetime import datetime

import pytest

from app.services.sync_ingest_service import _attendance_message, _clock


class _Attendance:
    def __init__(self, time_in=None, last_seen=None):
        self.time_in = time_in
        self.last_seen = last_seen


def test_arrival_names_the_hour():
    title, body = _attendance_message(
        "present", "Комрон Абдуллоев",
        _Attendance(time_in=datetime(2026, 8, 19, 8, 12)))
    assert "08:12" in body
    assert "Комрон Абдуллоев" in body
    assert title == "Фарзандатон ба мактаб омад"


def test_late_arrival_names_the_hour():
    title, body = _attendance_message(
        "late", "Нилуфар",
        _Attendance(time_in=datetime(2026, 8, 19, 8, 47)))
    assert "08:47" in body
    assert "дер" in title


def test_absent_carries_no_time():
    """The child was never seen, so any clock reading would describe the
    system giving up rather than anything about the child."""
    _title, body = _attendance_message(
        "absent", "Отабек", _Attendance(time_in=datetime(2026, 8, 19, 9, 0)))
    assert "соати" not in body
    assert "09:00" not in body


def test_left_school_uses_last_seen_not_arrival():
    _title, body = _attendance_message(
        "left_school", "Мадина",
        _Attendance(time_in=datetime(2026, 8, 19, 8, 5),
                    last_seen=datetime(2026, 8, 19, 13, 40)))
    assert "13:40" in body
    assert "08:05" not in body


def test_missing_time_still_sends_a_message():
    """A record synced without a timestamp must not silence the
    notification -- the parent still needs to know."""
    _title, body = _attendance_message("present", "Сардор", _Attendance())
    assert "Сардор" in body
    assert "соати" not in body


def test_unknown_status_sends_nothing():
    assert _attendance_message("teleported", "X", _Attendance()) is None


@pytest.mark.parametrize("value,expected", [
    (datetime(2026, 8, 19, 8, 5), "08:05"),
    ("2026-08-19T14:28:50.779176", "14:28"),
    (None, None),
    ("not a time", None),
])
def test_clock_formatting(value, expected):
    assert _clock(value) == expected


def test_clock_does_not_shift_the_hour():
    """Times arrive as the school's own local clock. Anything that looks
    like a timezone conversion here would move every parent's notification
    by hours."""
    assert _clock(datetime(2026, 8, 19, 23, 59)) == "23:59"
    assert _clock(datetime(2026, 8, 19, 0, 1)) == "00:01"
