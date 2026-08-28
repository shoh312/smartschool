"""The roll call at the start of a lesson.

A register is decided in the first few minutes of a lesson, not sampled at
random through it. The camera's duty cycle -- ten seconds of looking, then
twenty minutes of nothing -- answers "is the room occupied" well and "who
turned up" badly: a pupil who walks in at 14:02, or who has their back to
the lens at 14:00, is called absent on the strength of one glance, and the
correction only arrives at 14:20, long after their parent was told.

So the first ten minutes of a lesson are scanned continuously and the
verdict is passed once, at the end. What is tested here is where that
deadline falls -- including the awkward case of a camera that joins a
lesson whose roll call has already run out, where the wrong answer is to
judge a room nobody has looked at yet.
"""

from datetime import date, datetime, time, timedelta

from app.ai.live_detection import (
    ARRIVAL_MIN_LOOK_SECONDS,
    ARRIVAL_WINDOW_MINUTES,
    arrival_deadline_for,
)

MONDAY = date(2026, 8, 17)


def _at(hour: int, minute: int, second: int = 0) -> float:
    return datetime.combine(MONDAY, time(hour, minute, second)).timestamp()


def test_closes_ten_minutes_after_the_lesson_starts():
    """A lesson beginning at 14:00 has until 14:10 to fill its register."""
    deadline = arrival_deadline_for(time(14, 0), now=_at(14, 0), today=MONDAY)
    assert deadline == _at(14, 10)


def test_deadline_is_the_clock_not_the_moment_the_camera_noticed():
    """The camera resolves the lesson on a sixty-second refresh, so it often
    picks one up a minute or two in. The roll call still closes ten minutes
    after the lesson began -- not ten minutes after the camera woke up, which
    would stretch every window by however late the camera was."""
    deadline = arrival_deadline_for(time(14, 0), now=_at(14, 3), today=MONDAY)
    assert deadline == _at(14, 10)


def test_a_spent_window_still_buys_a_look_at_the_room():
    """Restarted mid-lesson, the ten minutes are already gone. Closing the
    roll call immediately would mark a class absent on no evidence at all --
    nothing has looked at them yet -- so the room gets a short look first."""
    now = _at(14, 40)
    deadline = arrival_deadline_for(time(14, 0), now=now, today=MONDAY)
    assert deadline == now + ARRIVAL_MIN_LOOK_SECONDS


def test_the_grace_look_is_never_shorter_than_the_restart_itself():
    """Right on the boundary the window has technically expired, and the
    same rule applies -- a deadline in the past would close the roll call on
    the very tick it opened."""
    now = _at(14, ARRIVAL_WINDOW_MINUTES)
    deadline = arrival_deadline_for(time(14, 0), now=now, today=MONDAY)
    assert deadline > now


def test_a_lesson_without_a_start_time_has_no_roll_call():
    """Nothing to anchor a window to. The caller falls back to counting
    sweeps, which is the older and weaker rule but the only one available."""
    assert arrival_deadline_for(None, now=_at(14, 0), today=MONDAY) is None


def test_a_lesson_later_today_is_not_open_yet():
    """Asked about a lesson that has not begun, the deadline is still its
    own -- the window opens when the lesson does, and the loop simply is not
    in it until then."""
    deadline = arrival_deadline_for(time(16, 20), now=_at(14, 0), today=MONDAY)
    assert deadline == _at(16, 30)
    assert deadline > _at(14, 0) + timedelta(minutes=ARRIVAL_WINDOW_MINUTES).total_seconds()


class _LessonRegister:
    """The loop's decision, as it behaves around one lesson.

    Models two things the camera thread does with a lesson: it records
    whoever the roll call sees, and it decides -- once -- who was missing.
    Every window after that is allowed to record a late arrival and nothing
    else, which is the guarantee this school asked for in as many words: a
    pupil counted in during the first ten minutes came to school, and the
    lens losing them at twenty past cannot take that back.
    """

    def __init__(self):
        self.seen: set[int] = set()
        self.absent: set[int] = set()
        self.roll_call_closed = False

    def spotted(self, student_id: int) -> None:
        self.seen.add(student_id)
        # Seeing somebody is always allowed to correct an absence -- a late
        # arrival is present, not permanently missing.
        self.absent.discard(student_id)

    def close_roll_call(self, roster: set[int]) -> set[int]:
        self.roll_call_closed = True
        self.absent = roster - self.seen
        return self.absent

    def sweep(self, roster: set[int]) -> set[int]:
        """An ordinary twenty-minute window. Marks nobody once the roll call
        has spoken."""
        if self.roll_call_closed:
            return set()
        self.absent = roster - self.seen
        return self.absent


ROSTER = {1, 2, 3}


def test_the_roll_call_decides_who_was_missing():
    register = _LessonRegister()
    register.spotted(1)
    register.spotted(2)
    assert register.close_roll_call(ROSTER) == {3}


def test_a_pupil_seen_early_survives_a_later_sweep():
    """The case the school named: found at 14:03, invisible at 14:20 --
    turned away, sitting behind someone, out of frame. Still present."""
    register = _LessonRegister()
    register.spotted(1)
    register.close_roll_call(ROSTER)
    assert register.sweep(ROSTER) == set()
    assert 1 not in register.absent


def test_later_sweeps_never_add_absences():
    """A pupil the roll call already judged absent is not re-judged every
    twenty minutes, which would send their parent the same alarm again."""
    register = _LessonRegister()
    register.close_roll_call(ROSTER)
    assert register.sweep(ROSTER) == set()


def test_a_late_arrival_is_still_corrected():
    """Nothing above stops the register from being put right. Walking in at
    14:25 clears the absence -- the verdict is one-way only against being
    made worse, never against being corrected."""
    register = _LessonRegister()
    assert register.close_roll_call(ROSTER) == {1, 2, 3}
    register.spotted(2)
    assert register.absent == {1, 3}


def test_a_restart_does_not_judge_the_lesson_twice():
    """The verdict is decided once and read back from the register, not from
    a flag in the process that passed it.

    A camera thread restarted mid-lesson used to open a fresh roll call and
    judge the class again: a pupil enrolled after the first verdict was
    marked absent a minute later, and one already absent had their parent
    told a second time. What the register already says outranks what this
    process happens to remember.
    """
    register = _LessonRegister()
    register.spotted(1)
    assert register.close_roll_call(ROSTER) == {2, 3}

    # The process dies here. A new one comes up, sees an absence already
    # written against this lesson, and does not re-open the window.
    restarted = _LessonRegister()
    restarted.roll_call_closed = True  # what lesson_verdict_passed() reports
    assert restarted.sweep(ROSTER | {4}) == set()


def test_a_pupil_enrolled_after_the_verdict_is_not_marked_absent():
    """The case that actually bit: a director adding a pupil to the group
    while the lesson runs. They were never looked for, so they are not
    evidence of anything -- the bell will fill their row in, not a restart."""
    register = _LessonRegister()
    register.close_roll_call(ROSTER)
    assert 4 not in register.sweep(ROSTER | {4})
