"""Maps calendar dates to the 4-chorak (quarter) academic calendar used by
Tajik schools. Exact chorak boundaries vary school-to-school (autumn/winter/
spring breaks shift a week or two year to year), so this is a default a
teacher can always override when entering a grade -- not an authoritative
school calendar.
"""

from datetime import date


def quarter_for_date(d: date) -> int:
    month = d.month
    if month in (9, 10):
        return 1
    if month in (11, 12):
        return 2
    if month in (1, 2, 3):
        return 3
    if month in (4, 5):
        return 4
    # Jun/Jul/Aug: summer break -- grades entered then (make-up exams, etc.)
    # are attributed to the 4th quarter that just finished.
    return 4


def current_quarter() -> int:
    return quarter_for_date(date.today())


def school_year_for_date(d: date) -> int:
    """The year a school year STARTS in, for date `d` -- e.g. any date from
    Sep 2026 through Aug 2027 belongs to school year 2026 (displayed as
    "2026-2027"). `quarter` alone (1-4) repeats every year, so this is what
    disambiguates "quarter 1" across different years -- without it, every
    quarter-scoped query silently blends grades from every year a student
    has ever attended once more than one school year of data exists.
    """
    return d.year if d.month >= 9 else d.year - 1


def current_school_year() -> int:
    return school_year_for_date(date.today())


def quarter_date_range(quarter: int, school_year: int | None = None) -> tuple[date, date]:
    """Approximate [start, end] calendar dates for a chorak in the given
    school year (defaults to the current one) -- used to scope
    lesson-attendance stats to the same quarter grades are grouped by.

    Takes `school_year` explicitly rather than inferring it from "today":
    inferring from today breaks for anyone requesting a past quarter after
    a new school year has started (e.g. requesting quarter 4 in September
    would otherwise resolve to next spring's Apr-May, not the one that just
    ended).
    """
    y = school_year if school_year is not None else current_school_year()
    ranges = {
        1: (date(y, 9, 1), date(y, 10, 31)),
        2: (date(y, 11, 1), date(y, 12, 31)),
        3: (date(y + 1, 1, 1), date(y + 1, 3, 31)),
        4: (date(y + 1, 4, 1), date(y + 1, 5, 31)),
    }
    return ranges[quarter]
