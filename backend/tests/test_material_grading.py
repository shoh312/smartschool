"""Marking and paste-import rules.

These are the functions that decide whether a pupil's answer was right, so
a silent regression here changes real marks in a real journal. They're pure
-- no database, no network -- which is exactly why they're worth pinning
down first.
"""

import pytest

from app.services.material_grading import (
    PasteImportError,
    is_answer_correct,
    parse_pasted_blocks,
    score_attempt,
    suggest_grade,
)


class _Block:
    """Minimal stand-in for a MaterialBlock row."""

    def __init__(self, block_id, question_type, correct, points=1):
        self.id = block_id
        self.question_type = question_type
        self.correct = correct
        self.points = points


# --------------------------------------------------------------------------
# Answer checking
# --------------------------------------------------------------------------

@pytest.mark.parametrize(
    "question_type, correct, answer, expected",
    [
        ("single", {"index": 0}, {"index": 0}, True),
        ("single", {"index": 0}, {"index": 1}, False),
        ("truefalse", {"value": True}, {"value": True}, True),
        ("truefalse", {"value": True}, {"value": False}, False),
        ("fill", {"answers": ["12"]}, {"text": "12"}, True),
        # Typed on a phone: stray spaces and a trailing full stop must not
        # cost a mark.
        ("fill", {"answers": ["12"]}, {"text": "  12. "}, True),
        ("fill", {"answers": ["Dushanbe"]}, {"text": "dushanbe"}, True),
        ("fill", {"answers": ["12"]}, {"text": "13"}, False),
        # Order of the connections doesn't matter, only which items joined.
        ("match", {"pairs": [[0, 1], [1, 0]]}, {"pairs": [[1, 0], [0, 1]]}, True),
        ("match", {"pairs": [[0, 1], [1, 0]]}, {"pairs": [[0, 1]]}, False),
        ("order", {"order": [1, 2, 0]}, {"order": [1, 2, 0]}, True),
        ("order", {"order": [1, 2, 0]}, {"order": [0, 1, 2]}, False),
    ],
)
def test_answer_checking(question_type, correct, answer, expected):
    assert is_answer_correct(question_type, correct, answer) is expected


@pytest.mark.parametrize(
    "question_type, correct, answer",
    [
        ("single", {"index": 0}, None),
        ("single", {"index": 0}, {}),
        ("single", {"index": 0}, {"index": "x"}),
        ("unknown-type", {"index": 0}, {"index": 0}),
        ("fill", {"answers": []}, {"text": "anything"}),
        ("match", {"pairs": []}, {"pairs": []}),
    ],
)
def test_malformed_answers_are_wrong_not_crashes(question_type, correct, answer):
    """A pupil mid-test must never hit a 500 because of a bad payload."""
    assert is_answer_correct(question_type, correct, answer) is False


# --------------------------------------------------------------------------
# Scoring
# --------------------------------------------------------------------------

def test_score_attempt_counts_points_not_questions():
    blocks = [
        _Block(1, "single", {"index": 0}, points=2),
        _Block(2, "truefalse", {"value": True}, points=3),
    ]
    answers = {"1": {"index": 0}, "2": {"value": False}}
    assert score_attempt(blocks, answers) == (2, 5)


def test_score_attempt_handles_integer_and_string_keys():
    """Block ids come back from Postgres JSON as strings; a resumed attempt
    saved them as ints. Both have to find the same block."""
    blocks = [_Block(7, "truefalse", {"value": True})]
    assert score_attempt(blocks, {7: {"value": True}}) == (1, 1)
    assert score_attempt(blocks, {"7": {"value": True}}) == (1, 1)


def test_unanswered_questions_still_count_towards_the_total():
    blocks = [_Block(1, "single", {"index": 0}), _Block(2, "single", {"index": 0})]
    assert score_attempt(blocks, {}) == (0, 2)


@pytest.mark.parametrize(
    "percent, expected",
    [(100, 5), (90, 5), (89, 4), (75, 4), (74, 3), (55, 3), (54, 2), (0, 2), (None, None)],
)
def test_suggested_grade_boundaries(percent, expected):
    assert suggest_grade(percent) == expected


# --------------------------------------------------------------------------
# Paste import
# --------------------------------------------------------------------------

def test_paste_reads_pages_questions_and_fill_answers():
    blocks = parse_pasted_blocks(
        "# Bugungi mavzu.\n"
        "Ikkinchi qator ham shu sahifaga kiradi.\n"
        "\n"
        "1. Poytaxt qayerda?\n"
        "* Dushanbe\n"
        "- Xujand\n"
        "\n"
        "2. 5 + 7 = ?\n"
        "= 12\n"
        "= o'n ikki\n"
    )
    assert [b["block_type"] for b in blocks] == ["page", "question", "question"]
    assert blocks[0]["body"].endswith("kiradi.")
    assert blocks[1]["options"] == ["Dushanbe", "Xujand"]
    assert blocks[1]["correct"] == {"index": 0}
    assert blocks[2]["question_type"] == "fill"
    assert blocks[2]["correct"] == {"answers": ["12", "o'n ikki"]}
    assert [b["position"] for b in blocks] == [0, 1, 2]


def test_paste_joins_a_question_wrapped_over_two_lines():
    blocks = parse_pasted_blocks("1. Yer Quyosh\n   atrofida aylanadimi?\n* Ha\n- Yo'q\n")
    assert blocks[0]["body"] == "Yer Quyosh atrofida aylanadimi?"


@pytest.mark.parametrize(
    "text",
    [
        "salom",                              # no question marker at all
        "1. savol",                           # question with no answer
        "1. savol\n* a\n* b\n",               # two correct options
        "1. savol\n* a\n",                    # only one option
        "1. savol\n* a\n- b\n= 12\n",         # options and a typed answer
    ],
)
def test_paste_rejects_unusable_input(text):
    with pytest.raises(PasteImportError):
        parse_pasted_blocks(text)
