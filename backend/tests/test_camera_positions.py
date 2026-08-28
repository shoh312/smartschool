# -*- coding: utf-8 -*-
"""Which group a camera is watching, in a room several groups pass through.

A school gives each class its own room, so one camera means one class. An
academy runs Python 4 through a room at nine and Java 2 through the same room
at two, and a camera bound to one class can only ever recognise one of them --
the other group is invisible to it, every day, silently.

These are the rules that decide whose faces to load.
"""

import pytest

from app.services.camera_position_service import (
    Slot,
    active_slot,
    conflicts_with,
    normalise_time,
    valid_time,
)

MONDAY, TUESDAY = 0, 1

MORNING = Slot(id=1, class_id=10, start_time="09:00", end_time="11:00")
AFTERNOON = Slot(id=2, class_id=20, start_time="14:00", end_time="16:00")


def test_the_morning_group_is_found_in_the_morning():
    assert active_slot([MORNING, AFTERNOON], MONDAY, "09:30").class_id == 10


def test_the_afternoon_group_is_found_after_lunch():
    assert active_slot([MORNING, AFTERNOON], MONDAY, "15:00").class_id == 20


def test_between_the_two_the_room_is_empty():
    """Not "whoever was here last" -- an empty room must load no roster, or
    the midday cleaner gets marked present for Python 4."""
    assert active_slot([MORNING, AFTERNOON], MONDAY, "12:00") is None


def test_a_slot_ends_the_moment_the_next_one_starts():
    """Back to back, not overlapping: at 11:00 the morning group has gone."""
    back_to_back = Slot(id=3, class_id=30, start_time="11:00", end_time="13:00")
    assert active_slot([MORNING, back_to_back], MONDAY, "11:00").class_id == 30


def test_an_everyday_slot_covers_every_weekday():
    assert active_slot([MORNING], MONDAY, "10:00") is not None
    assert active_slot([MORNING], TUESDAY, "10:00") is not None


def test_a_day_specific_slot_only_covers_its_day():
    monday_only = Slot(id=4, class_id=40, start_time="09:00", end_time="11:00", day_of_week=MONDAY)
    assert active_slot([monday_only], MONDAY, "10:00") is not None
    assert active_slot([monday_only], TUESDAY, "10:00") is None


def test_a_day_specific_slot_beats_an_everyday_one():
    """The specific entry is the exception someone deliberately added, so it
    is the one they meant -- otherwise a Monday swap would need the general
    slot deleted and recreated around it."""
    monday_swap = Slot(id=5, class_id=99, start_time="09:00", end_time="11:00", day_of_week=MONDAY)
    assert active_slot([MORNING, monday_swap], MONDAY, "10:00").class_id == 99
    assert active_slot([MORNING, monday_swap], TUESDAY, "10:00").class_id == 10


def test_two_groups_cannot_share_an_hour():
    overlapping = Slot(id=None, class_id=50, start_time="10:00", end_time="12:00")
    assert conflicts_with([MORNING, AFTERNOON], overlapping) is MORNING


def test_touching_slots_do_not_conflict():
    touching = Slot(id=None, class_id=50, start_time="11:00", end_time="14:00")
    assert conflicts_with([MORNING, AFTERNOON], touching) is None


def test_editing_a_slot_does_not_conflict_with_itself():
    """Saving the same slot back with a new end time must not be refused for
    overlapping the row it is replacing."""
    edited = Slot(id=1, class_id=10, start_time="09:00", end_time="11:30")
    assert conflicts_with([MORNING, AFTERNOON], edited) is None


def test_slots_on_different_days_never_conflict():
    monday = Slot(id=None, class_id=60, start_time="09:00", end_time="11:00", day_of_week=MONDAY)
    tuesday = Slot(id=7, class_id=70, start_time="09:00", end_time="11:00", day_of_week=TUESDAY)
    assert conflicts_with([tuesday], monday) is None


@pytest.mark.parametrize("value,stored", [("08:00", "08:00"), ("8:00", "08:00"), ("9:5", "09:05")])
def test_times_are_zero_padded(value, stored):
    assert normalise_time(value) == stored


@pytest.mark.parametrize("value", ["25:00", "08:60", "1345", "8", "", "nimadir"])
def test_an_unparseable_time_is_refused(value):
    """Same reason as the lesson timetable: a time nothing can parse becomes
    a slot that silently never matches."""
    assert not valid_time(value)


def test_a_group_whose_slot_has_started_can_be_marked_absent():
    """The day-level absence job reads the lesson timetable to know who was
    expected in. An academy has no lessons, only these slots -- without this
    every group in group mode is silently exempt from ever being absent."""
    from app.services.camera_position_service import classes_with_started_slot

    assert classes_with_started_slot([MORNING, AFTERNOON], MONDAY, "09:30", grace_minutes=0) == {10}


def test_a_finished_slot_still_counts():
    """A group whose hour ended and who never appeared is absent -- the mark
    is made after the fact, not only while they could still walk in."""
    from app.services.camera_position_service import classes_with_started_slot

    assert classes_with_started_slot([MORNING, AFTERNOON], MONDAY, "17:00", grace_minutes=0) == {10, 20}


def test_a_slot_that_has_not_begun_counts_for_nothing():
    """At eight in the morning nobody is late for a nine o'clock group."""
    from app.services.camera_position_service import classes_with_started_slot

    assert classes_with_started_slot([MORNING, AFTERNOON], MONDAY, "08:00", grace_minutes=0) == set()


def test_another_days_slot_is_not_todays_absence():
    from app.services.camera_position_service import classes_with_started_slot

    tuesday_only = Slot(id=9, class_id=80, start_time="09:00", end_time="11:00", day_of_week=TUESDAY)
    assert classes_with_started_slot([tuesday_only], MONDAY, "12:00", grace_minutes=0) == set()
    assert classes_with_started_slot([tuesday_only], TUESDAY, "12:00", grace_minutes=0) == {80}


def test_the_clock_waits_before_overruling_the_camera():
    """The camera decides first -- two sweeps of the room. This is only the
    backstop for when it cannot look at all, so it must not beat the camera
    to the verdict: at 11:07 a group that started at 11:00 has been looked at
    once at most, and a duty cycle can be twenty minutes wide.

    This is the academy's version of the bug that marked two pupils absent
    seven minutes into their first lesson, before anything had seen them.
    """
    from app.services.camera_position_service import (
        ABSENCE_GRACE_MINUTES,
        classes_with_started_slot,
    )

    slot = Slot(id=1, class_id=10, start_time="11:00", end_time="13:00")
    assert classes_with_started_slot([slot], MONDAY, "11:07") == set()
    assert classes_with_started_slot([slot], MONDAY, "11:29") == set()
    assert classes_with_started_slot([slot], MONDAY, "11:30") == {10}
    assert ABSENCE_GRACE_MINUTES == 30
