"""When a control test's marks may be shown.

This is the school's own rule, and the reason the feature is trusted: the
first pupil to finish must not be able to learn their score -- and by
extension which answers were right -- while the rest of the class is still
working. Practice work has nothing to hide.
"""

from datetime import datetime, timedelta

import pytest

from app.services.material_service import results_are_visible


class _Assignment:
    def __init__(self, mode, due_at=None):
        self.mode = mode
        self.due_at = due_at


NOW = datetime(2026, 8, 16, 12, 0)
LATER = NOW + timedelta(hours=2)
EARLIER = NOW - timedelta(hours=2)


def test_practice_results_are_visible_immediately():
    """Nothing to protect: it isn't graded and the pupil is told right or
    wrong as they go."""
    assignment = _Assignment("practice")
    assert results_are_visible(assignment, 20, 1, NOW) is True


def test_a_running_control_test_hides_its_marks():
    assignment = _Assignment("control", due_at=LATER)
    assert results_are_visible(assignment, 20, 19, NOW) is False


def test_a_control_test_opens_once_the_deadline_passes():
    assignment = _Assignment("control", due_at=EARLIER)
    assert results_are_visible(assignment, 20, 0, NOW) is True


def test_a_control_test_opens_early_when_everyone_has_submitted():
    """Waiting out the clock serves no purpose once nobody is left to
    protect."""
    assignment = _Assignment("control", due_at=LATER)
    assert results_are_visible(assignment, 20, 20, NOW) is True


def test_an_empty_class_does_not_count_as_everyone_submitting():
    """0 >= 0 is true, which would have unlocked a control test in a class
    with no pupils in it."""
    assignment = _Assignment("control", due_at=LATER)
    assert results_are_visible(assignment, 0, 0, NOW) is False


def test_a_control_test_without_a_deadline_stays_shut_until_all_submit():
    """The server refuses to create one of these for exactly this reason --
    a single absent pupil would lock the marks away for good."""
    assignment = _Assignment("control", due_at=None)
    assert results_are_visible(assignment, 20, 19, NOW) is False
    assert results_are_visible(assignment, 20, 20, NOW) is True


@pytest.mark.parametrize("submitted", [0, 5, 19])
def test_partial_submission_never_opens_a_running_control_test(submitted):
    assignment = _Assignment("control", due_at=LATER)
    assert results_are_visible(assignment, 20, submitted, NOW) is False
