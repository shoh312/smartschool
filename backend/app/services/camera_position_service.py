# -*- coding: utf-8 -*-
"""Which group is in front of a camera right now.

Only consulted when the school has group mode on. Without it a camera keeps
belonging to a single class, which is right for a school where every class
has its own room and wrong for an academy where one room sees five groups a
day.

The functions that decide are pure so the rule can be tested without a
camera, a database or a clock -- the queries live in the router and the
detection loop.
"""

import re
from dataclasses import dataclass

_TIME = re.compile(r"^([01]?\d|2[0-3]):[0-5]\d$")


def valid_time(value: str) -> bool:
    return bool(_TIME.match((value or "").strip()))


def normalise_time(value: str) -> str:
    """`8:00` -> `08:00`, so slots sort and compare as text."""
    hours, minutes = value.strip().split(":")
    return "%02d:%02d" % (int(hours), int(minutes))


def _minutes(value: str) -> int:
    hours, minutes = value.split(":")
    return int(hours) * 60 + int(minutes)


@dataclass(frozen=True)
class Slot:
    """Just enough of a CameraPosition to reason about. `day_of_week` is
    None for a slot that repeats every day."""

    class_id: int
    start_time: str
    end_time: str
    day_of_week: int | None = None
    id: int | None = None


def covers(slot: Slot, weekday: int, clock: str) -> bool:
    """Is this slot the one running at `clock` on `weekday`?

    Half-open on purpose: a slot ending at 11:00 and one starting at 11:00
    are back to back, not overlapping, and the group that has just arrived is
    the one the camera should be looking for.
    """
    if slot.day_of_week is not None and slot.day_of_week != weekday:
        return False
    return _minutes(slot.start_time) <= _minutes(clock) < _minutes(slot.end_time)


def active_slot(slots: list[Slot], weekday: int, clock: str) -> Slot | None:
    """The slot in force, or None when the room is empty.

    A day-specific slot wins over an every-day one covering the same hour:
    the specific entry is the exception somebody deliberately added, so it is
    the one they meant.
    """
    matching = [slot for slot in slots if covers(slot, weekday, clock)]
    if not matching:
        return None
    matching.sort(key=lambda slot: (slot.day_of_week is None, slot.start_time))
    return matching[0]


# How long after a slot begins before the clock alone may call somebody
# absent.
#
# The camera decides first: two sweeps of the room and anyone still unseen is
# marked (see ABSENT_AFTER_CYCLES). This is only the backstop for when the
# camera cannot -- it is unplugged, the network moved, the stream is down --
# and it has to be long enough that it never beats the camera to the verdict.
# A duty cycle can be twenty minutes wide, so thirty gives the room a real
# look before the clock overrules it.
#
# Set too low it marks pupils absent the minute their lesson starts, before
# anything has looked at them, which is exactly what the two-sweep rule was
# built to prevent.
ABSENCE_GRACE_MINUTES = 30


def classes_with_started_slot(
    slots: list[Slot],
    weekday: int,
    clock: str,
    grace_minutes: int = ABSENCE_GRACE_MINUTES,
) -> set[int]:
    """Groups whose slot began at least `grace_minutes` ago.

    The day-level absence job needs to know which groups were expected in at
    all, the way a school's version reads it off the lesson timetable. An
    academy has no lessons, only these slots -- so without this every group in
    group mode would be permanently exempt from being marked absent, and
    nothing would say why.

    "Began", not "running": a group whose slot ended an hour ago and who never
    appeared is still absent, and one whose slot begins this afternoon is not
    yet anything.
    """
    return {
        slot.class_id
        for slot in slots
        if (slot.day_of_week is None or slot.day_of_week == weekday)
        and _minutes(slot.start_time) + grace_minutes <= _minutes(clock)
    }


def conflicts_with(existing: list[Slot], candidate: Slot) -> Slot | None:
    """The slot a new one would overlap, or None.

    Two groups cannot be in one room at one time, and the director should be
    told which slot they are colliding with rather than being left to find it
    themselves in the list.
    """
    for slot in existing:
        if slot.id is not None and slot.id == candidate.id:
            continue
        days_can_meet = (
            slot.day_of_week is None
            or candidate.day_of_week is None
            or slot.day_of_week == candidate.day_of_week
        )
        if not days_can_meet:
            continue
        if _minutes(candidate.start_time) < _minutes(slot.end_time) and _minutes(
            slot.start_time
        ) < _minutes(candidate.end_time):
            return slot
    return None
