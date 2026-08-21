"""When the cameras are allowed to call a student absent.

A single detect window is ten seconds long. A child walking through the
door, or simply turned away from the lens for those ten seconds, is missed
by one sweep -- and marking them absent on that basis sends their parent a
false alarm about their own child. So the rule is that absence needs two
passes: the room has to have been looked at twice.

The case worth guarding is the day boundary. A camera thread runs for weeks
without restarting, and a count carried over from yesterday would mean the
very first sweep of the morning is treated as the second -- marking a whole
class absent before anybody has walked in.
"""

from datetime import date

from app.services.attendance_service import DetectionCycleCounter

MONDAY = date(2026, 8, 17)
TUESDAY = date(2026, 8, 18)


def test_first_pass_is_not_enough():
    """One look at an empty seat proves nothing -- the child may be at the
    door."""
    counter = DetectionCycleCounter(threshold=2, today=MONDAY)
    assert counter.record(MONDAY) is False


def test_second_pass_decides():
    counter = DetectionCycleCounter(threshold=2, today=MONDAY)
    counter.record(MONDAY)
    assert counter.record(MONDAY) is True


def test_stays_decided_for_the_rest_of_the_day():
    """Later sweeps keep marking whoever is still missing -- a student who
    never arrives should not be left without a record because the third
    sweep 'already happened'."""
    counter = DetectionCycleCounter(threshold=2, today=MONDAY)
    counter.record(MONDAY)
    counter.record(MONDAY)
    assert counter.record(MONDAY) is True
    assert counter.record(MONDAY) is True


def test_new_day_starts_over():
    """The bug this class exists to prevent: yesterday's count must not make
    this morning's first sweep count as the second."""
    counter = DetectionCycleCounter(threshold=2, today=MONDAY)
    counter.record(MONDAY)
    counter.record(MONDAY)
    assert counter.record(MONDAY) is True

    assert counter.record(TUESDAY) is False, (
        "first sweep of a new day must not mark anyone absent"
    )
    assert counter.count == 1


def test_new_day_then_reaches_threshold_again():
    counter = DetectionCycleCounter(threshold=2, today=MONDAY)
    counter.record(MONDAY)
    counter.record(MONDAY)
    counter.record(TUESDAY)
    assert counter.record(TUESDAY) is True


def test_threshold_of_one_decides_immediately():
    """A school that wants the old behaviour back can set it to one."""
    counter = DetectionCycleCounter(threshold=1, today=MONDAY)
    assert counter.record(MONDAY) is True
