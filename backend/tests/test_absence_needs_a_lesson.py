"""When the school is allowed to call a pupil absent for the day.

The camera can only report who it saw. Turning "nobody saw them" into "they
were absent" is a claim about where the child was supposed to be, and the
only record of that is the timetable. Without consulting it, the job marked
every active pupil absent every day after the morning cutoff -- which is how
the database collected 56 Sunday absences, and 842 absences against a single
present.

The three cases that matter are a normal school day, a day nobody has
lessons (a Sunday, a holiday), and a class whose timetable the school has
not entered yet -- that last one is silence, not truancy.
"""

from app.services.attendance_service import classes_in_session_on

MONDAY, SATURDAY, SUNDAY = 0, 5, 6


class _Lesson:
    def __init__(self, class_id, day_of_week):
        self.class_id = class_id
        self.day_of_week = day_of_week


TIMETABLE = [
    _Lesson(class_id=9, day_of_week=MONDAY),
    _Lesson(class_id=9, day_of_week=SATURDAY),
    _Lesson(class_id=13, day_of_week=MONDAY),
]


def test_a_school_day_names_the_classes_that_have_lessons():
    assert classes_in_session_on(TIMETABLE, MONDAY) == {9, 13}


def test_sunday_has_nobody_in_session():
    """The whole point: an empty set means the job marks no one."""
    assert classes_in_session_on(TIMETABLE, SUNDAY) == set()


def test_a_class_without_a_saturday_lesson_is_left_alone():
    """9 has school on Saturday and 13 does not, so only 9 can be absent."""
    assert classes_in_session_on(TIMETABLE, SATURDAY) == {9}


def test_a_school_with_no_timetable_at_all_marks_nobody():
    """Newly set up school: a blank timetable is not a school-wide truancy."""
    assert classes_in_session_on([], MONDAY) == set()


class _Timed:
    def __init__(self, class_id, day_of_week, start_time):
        self.class_id = class_id
        self.day_of_week = day_of_week
        self.start_time = start_time


AFTERNOON_GROUP = [_Timed(class_id=30, day_of_week=MONDAY, start_time="14:00")]


def test_an_afternoon_group_is_not_absent_in_the_morning():
    """The bug the academy hit: a group whose only lesson starts at 14:00 was
    reported absent from 08:15, because having a lesson somewhere in the day
    counted as being late for it. A school never noticed -- its first lesson
    starts before the cutoff -- but an afternoon group is not late at
    breakfast."""
    assert classes_in_session_on(AFTERNOON_GROUP, MONDAY, "09:30") == set()


def test_the_same_group_is_absent_once_its_hour_has_come():
    assert classes_in_session_on(AFTERNOON_GROUP, MONDAY, "14:30") == {30}


def test_it_still_counts_after_the_lesson_has_finished():
    """Somebody who never turned up is still absent at six in the evening."""
    assert classes_in_session_on(AFTERNOON_GROUP, MONDAY, "18:00") == {30}


def test_without_a_clock_the_old_whole_day_meaning_is_kept():
    """Callers that only ask "does this class have school today" -- the
    Sunday check -- must keep working unchanged."""
    assert classes_in_session_on(AFTERNOON_GROUP, MONDAY) == {30}
    assert classes_in_session_on(AFTERNOON_GROUP, SUNDAY) == set()
