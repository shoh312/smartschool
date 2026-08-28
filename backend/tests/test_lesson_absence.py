# -*- coding: utf-8 -*-
"""Marking a pupil absent from one lesson, while the lesson is running.

The rule the school asked for: the camera looks at the room when the lesson
starts, says nothing on the first sweep, and on the second sweep writes an
absence into that subject's register.

Two sweeps rather than one for the same reason the day-level rule uses two --
a child walking through the door, or facing away from the lens for ten
seconds, is missed by a single look, and one look is not evidence of absence.

The counter is per lesson, not per day: a pupil present for Maths and gone by
Physics has to be absent from Physics, and the number of times the room has
been looked at since morning says nothing about that.
"""

from app.services.attendance_service import DetectionCycleCounter


class _LessonCycles:
    """The loop's own counter, as it behaves around the bell: it counts
    sweeps and resets when the active lesson changes."""

    def __init__(self, threshold):
        self.threshold = threshold
        self.count = 0
        self.lesson_id = None

    def sweep(self, lesson_id):
        if lesson_id != self.lesson_id:
            self.lesson_id = lesson_id
            self.count = 0
        self.count += 1
        return self.count >= self.threshold


def test_one_sweep_is_not_enough():
    cycles = _LessonCycles(2)
    assert cycles.sweep(lesson_id=10) is False


def test_the_second_sweep_decides():
    cycles = _LessonCycles(2)
    cycles.sweep(lesson_id=10)
    assert cycles.sweep(lesson_id=10) is True


def test_the_next_lesson_starts_from_zero():
    """Otherwise the bell rings, the class changes, and everyone missing from
    the first sweep of the new lesson is absent on the strength of a count
    that belonged to the previous one."""
    cycles = _LessonCycles(2)
    cycles.sweep(lesson_id=10)
    cycles.sweep(lesson_id=10)

    assert cycles.sweep(lesson_id=11) is False
    assert cycles.sweep(lesson_id=11) is True


def test_later_sweeps_keep_deciding():
    """A pupil who never arrives must still be marked when the third and
    fourth sweeps run, not only on the second."""
    cycles = _LessonCycles(2)
    cycles.sweep(lesson_id=10)
    assert cycles.sweep(lesson_id=10) is True
    assert cycles.sweep(lesson_id=10) is True


def test_the_day_counter_is_a_separate_thing():
    """Both exist: the day-level one decides "did not come to school", the
    lesson-level one decides "was not in this lesson". Sharing a counter
    would make the first lesson of the day the only one that could ever mark
    anybody."""
    day = DetectionCycleCounter(threshold=2)
    lesson = _LessonCycles(2)

    from datetime import date

    today = date(2026, 8, 24)
    day.record(today)
    lesson.sweep(lesson_id=10)

    # Second sweep of the day, but the first of a new lesson.
    assert day.record(today) is True
    assert lesson.sweep(lesson_id=11) is False
