"""Phone normalisation and the school calendar.

Both decide identity or dates, and both have already caused real damage
once: two parent rows for one person because "987644002" and
"+992 987 64 40 02" hashed to different keys, and control-test deadlines
landing five hours late because a wall-clock time was read as UTC.
"""

from datetime import date, datetime, timedelta, timezone

import pytest

from app.schemas.material_schema import SCHOOL_TZ, to_utc_naive
from app.utils.academic_calendar import quarter_for_date, school_year_for_date
from app.utils.phone import normalize_phone


# --------------------------------------------------------------------------
# Phone numbers
# --------------------------------------------------------------------------

@pytest.mark.parametrize(
    "written",
    [
        "987644002",
        "0987644002",
        "992987644002",
        "+992987644002",
        "+992 987 64 40 02",
        "00992987644002",
        " 992-987-644-002 ",
    ],
)
def test_every_way_of_writing_the_same_number_is_one_key(written):
    """The whole point: one person, one parent row, whichever way the
    number was typed."""
    assert normalize_phone(written) == "992987644002"


@pytest.mark.parametrize("foreign", ["998901234567", "79161234567"])
def test_a_foreign_number_is_left_alone(foreign):
    """Digits-only, but never bent into a Tajik number -- an Uzbek or
    Russian number must not be mangled to satisfy this function."""
    assert normalize_phone(foreign) == foreign


@pytest.mark.parametrize("junk, expected", [("", ""), ("abc", ""), ("+++", "")])
def test_nonsense_normalises_to_nothing_rather_than_raising(junk, expected):
    assert normalize_phone(junk) == expected


# --------------------------------------------------------------------------
# Deadlines
# --------------------------------------------------------------------------

def test_a_bare_wall_clock_deadline_is_read_as_school_time():
    """17:00 typed on a phone in Dushanbe is 12:00 UTC. Taking it at face
    value gave every class an extra five hours on every control test."""
    assert to_utc_naive(datetime(2026, 8, 13, 17, 0)) == datetime(2026, 8, 13, 12, 0)


def test_an_offset_aware_deadline_is_converted_not_reinterpreted():
    aware = datetime(2026, 8, 13, 17, 0, tzinfo=SCHOOL_TZ)
    assert to_utc_naive(aware) == datetime(2026, 8, 13, 12, 0)


def test_a_utc_deadline_survives_unchanged():
    aware = datetime(2026, 8, 13, 12, 0, tzinfo=timezone.utc)
    assert to_utc_naive(aware) == datetime(2026, 8, 13, 12, 0)


def test_the_result_is_always_naive_so_it_compares_against_utcnow():
    assert to_utc_naive(datetime(2026, 8, 13, 17, 0)).tzinfo is None


def test_no_deadline_stays_no_deadline():
    assert to_utc_naive(None) is None


# --------------------------------------------------------------------------
# School year
# --------------------------------------------------------------------------

def test_autumn_belongs_to_the_year_it_starts_in():
    assert school_year_for_date(date(2026, 9, 15)) == 2026
    assert school_year_for_date(date(2026, 12, 31)) == 2026


def test_spring_still_belongs_to_the_previous_september():
    """Otherwise a January grade lands in a different school year from the
    December one beside it, and every quarter average splits in two."""
    assert school_year_for_date(date(2027, 1, 5)) == 2026
    assert school_year_for_date(date(2027, 5, 20)) == 2026


def test_quarters_advance_through_the_year():
    quarters = [quarter_for_date(date(2026, month, 15)) for month in (9, 11, 2, 5)]
    assert quarters == sorted(set(quarters), key=quarters.index)
    assert all(1 <= q <= 4 for q in quarters)
