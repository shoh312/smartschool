# -*- coding: utf-8 -*-
"""A timetable time that cannot be parsed must be refused, not stored.

Everything downstream reads start_time with int(hh), int(mm) and treats a
failure as "no lesson": _parse_start returns None, so the camera never opens
a window for that slot and absence never counts it. Nothing raises, nothing
is logged, and the lesson sits in the timetable looking perfectly correct --
which is indistinguishable, from the director's chair, from a broken camera.

So the only place it can be caught is on the way in.
"""

import pytest
from pydantic import ValidationError

from app.schemas.lesson_schema import LessonCreate, LessonUpdate


def _lesson(start_time):
    return LessonCreate(
        class_id=1, subject="Математика", day_of_week=5, start_time=start_time
    )


@pytest.mark.parametrize("value,stored", [
    ("08:00", "08:00"),
    ("8:00", "08:00"),      # zero-padded, so the diary's text sort still works
    ("13:45", "13:45"),
    ("00:05", "00:05"),
    ("23:59", "23:59"),
    (" 09:30 ", "09:30"),
])
def test_a_real_time_is_kept(value, stored):
    assert _lesson(value).start_time == stored


@pytest.mark.parametrize("value", [
    "13.45",    # the dot a numeric keypad offers instead of a colon
    "1345",
    "8",
    "25:00",
    "08:60",
    "",
    "нимрӯзӣ",
])
def test_anything_unparseable_is_refused(value):
    with pytest.raises(ValidationError):
        _lesson(value)


def test_an_edit_is_held_to_the_same_rule():
    with pytest.raises(ValidationError):
        LessonUpdate(start_time="13.45")


def test_an_edit_that_leaves_the_time_alone_is_fine():
    """Every other field can be patched without resending the time."""
    assert LessonUpdate(room="204").start_time is None


def test_a_lesson_cannot_run_for_zero_minutes():
    """A zero-length lesson ends before it starts, so its window never opens
    -- the same invisible failure by another route."""
    with pytest.raises(ValidationError):
        LessonCreate(class_id=1, subject="x", day_of_week=0, start_time="08:00", duration_minutes=0)
