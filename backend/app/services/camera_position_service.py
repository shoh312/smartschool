
import re
from dataclasses import dataclass

_TIME = re.compile(r"^([01]?\d|2[0-3]):[0-5]\d$")


def valid_time(value: str) -> bool:
    return bool(_TIME.match((value or "").strip()))


def normalise_time(value: str) -> str:
    hours, minutes = value.strip().split(":")
    return "%02d:%02d" % (int(hours), int(minutes))


def _minutes(value: str) -> int:
    hours, minutes = value.split(":")
    return int(hours) * 60 + int(minutes)


@dataclass(frozen=True)
class Slot:

    class_id: int
    start_time: str
    end_time: str
    day_of_week: int | None = None
    id: int | None = None


def covers(slot: Slot, weekday: int, clock: str) -> bool:
    if slot.day_of_week is not None and slot.day_of_week != weekday:
        return False
    return _minutes(slot.start_time) <= _minutes(clock) < _minutes(slot.end_time)


def active_slot(slots: list[Slot], weekday: int, clock: str) -> Slot | None:
    matching = [slot for slot in slots if covers(slot, weekday, clock)]
    if not matching:
        return None
    matching.sort(key=lambda slot: (slot.day_of_week is None, slot.start_time))
    return matching[0]


ABSENCE_GRACE_MINUTES = 30


def classes_with_started_slot(
    slots: list[Slot],
    weekday: int,
    clock: str,
    grace_minutes: int = ABSENCE_GRACE_MINUTES,
) -> set[int]:
    return {
        slot.class_id
        for slot in slots
        if (slot.day_of_week is None or slot.day_of_week == weekday)
        and _minutes(slot.start_time) + grace_minutes <= _minutes(clock)
    }


def conflicts_with(existing: list[Slot], candidate: Slot) -> Slot | None:
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
