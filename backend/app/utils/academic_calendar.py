
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
    return 4


def current_quarter() -> int:
    return quarter_for_date(date.today())


def school_year_for_date(d: date) -> int:
    return d.year if d.month >= 9 else d.year - 1


def current_school_year() -> int:
    return school_year_for_date(date.today())


def quarter_date_range(quarter: int, school_year: int | None = None) -> tuple[date, date]:
    y = school_year if school_year is not None else current_school_year()
    ranges = {
        1: (date(y, 9, 1), date(y, 10, 31)),
        2: (date(y, 11, 1), date(y, 12, 31)),
        3: (date(y + 1, 1, 1), date(y + 1, 3, 31)),
        4: (date(y + 1, 4, 1), date(y + 1, 5, 31)),
    }
    return ranges[quarter]
