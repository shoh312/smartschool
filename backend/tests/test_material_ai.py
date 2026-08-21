"""The validation layer that stands between Gemini and a pupil's test.

Everything the model produces passes through here. A question that slips
past it unanswerable can't be answered correctly no matter what the pupil
does, and nobody finds out until the test is marked -- so the rule is that
anything questionable is dropped, and these tests pin down exactly what
"questionable" means.
"""

import pytest

from app.services.material_ai_service import (
    MaterialAiError,
    _count_by_type,
    _distribute,
    _trim_questions,
    _validate,
    _validate_block,
)


def question(**overrides):
    base = {"block_type": "question", "body": "Savol?", "question_type": "single",
            "options": ["a", "b"], "answer": "a"}
    base.update(overrides)
    return base


# --------------------------------------------------------------------------
# Per-block validation
# --------------------------------------------------------------------------

def test_single_resolves_the_answer_by_text_not_index():
    block = _validate_block(question(options=["5", "2", "10"], answer="2"))
    assert block["correct"] == {"index": 1}


@pytest.mark.parametrize("answer", ["  5. ", "5)", "5"])
def test_single_tolerates_punctuation_the_model_adds(answer):
    """The model writes the option back as "5." or "5)" constantly; losing a
    good question to a trailing full stop would be absurd."""
    block = _validate_block(question(options=["5", "2"], answer=answer))
    assert block["correct"] == {"index": 0}


@pytest.mark.parametrize(
    "raw",
    [
        question(answer="9"),                       # answer isn't one of the options
        question(options=["a"], answer="a"),        # only one option
        question(options=["a", "a"], answer="a"),   # duplicate = two right answers
        question(answer=""),                        # no answer at all
        question(question_type="essay"),            # a type we don't support
        question(body=""),                          # no question text
        {"block_type": "question", "body": "q"},    # no type, no answer
    ],
)
def test_unanswerable_single_choice_is_dropped(raw):
    assert _validate_block(raw) is None


@pytest.mark.parametrize("answer, expected", [("true", True), ("false", False), ("Дуруст", True)])
def test_truefalse_accepts_the_words_the_model_uses(answer, expected):
    block = _validate_block(question(question_type="truefalse", options=[], answer=answer))
    assert block["correct"] == {"value": expected}


def test_truefalse_without_a_recognisable_answer_is_dropped():
    assert _validate_block(question(question_type="truefalse", options=[], answer="maybe")) is None


def test_fill_splits_spelling_variants_on_the_pipe():
    block = _validate_block(question(question_type="fill", options=[], answer="10|dah"))
    assert block["correct"] == {"answers": ["10", "dah"]}


def test_match_pairs_come_from_one_line_each():
    """Two separate lists used to come back different lengths; one line per
    pair makes that impossible."""
    block = _validate_block(question(
        question_type="match",
        options=["Suръat = m/s", "Masofa = metr", "Vaqt = soniya"],
        answer="",
    ))
    assert block["options"] == {"left": ["Suръat", "Masofa", "Vaqt"],
                                "right": ["m/s", "metr", "soniya"]}
    assert block["correct"] == {"pairs": [[0, 0], [1, 1], [2, 2]]}


def test_match_needs_at_least_two_usable_pairs():
    assert _validate_block(question(question_type="match", options=["only one = pair"], answer="")) is None


def test_order_is_authored_in_the_correct_sequence():
    block = _validate_block(question(question_type="order", options=["bir", "ikki", "uch"], answer=""))
    assert block["correct"] == {"order": [0, 1, 2]}


def test_page_keeps_its_paragraph_breaks():
    block = _validate_block({"block_type": "page", "body": "Birinchi.\n\nIkkinchi."})
    assert block["body"] == "Birinchi.\n\nIkkinchi."


# --------------------------------------------------------------------------
# Whole-response validation
# --------------------------------------------------------------------------

def test_validate_counts_what_it_dropped():
    parsed = {"title": "T", "blocks": [question(), question(answer="nope"), question(answer="b")]}
    result = _validate(parsed, "lesson")
    assert len(result["blocks"]) == 2
    assert result["dropped_count"] == 1


def test_test_mode_strips_explanation_pages():
    parsed = {"title": "T", "blocks": [{"block_type": "page", "body": "matn"}, question()]}
    result = _validate(parsed, "test")
    assert all(b["block_type"] == "question" for b in result["blocks"])


def test_a_response_with_no_usable_question_is_an_error():
    with pytest.raises(MaterialAiError):
        _validate({"title": "T", "blocks": [question(answer="nope")]}, "lesson")


# --------------------------------------------------------------------------
# Count and spread
# --------------------------------------------------------------------------

@pytest.mark.parametrize(
    "count, types, expected",
    [
        (10, ["single", "truefalse", "fill"], {"single": 4, "truefalse": 3, "fill": 3}),
        (10, ["single", "truefalse", "fill", "order", "match"],
         {"single": 2, "truefalse": 2, "fill": 2, "order": 2, "match": 2}),
        (3, ["single"], {"single": 3}),
    ],
)
def test_quota_covers_every_requested_type_and_sums_to_the_total(count, types, expected):
    """Without a quota the model wrote almost nothing but true/false."""
    quota = _distribute(count, types)
    assert quota == expected
    assert sum(quota.values()) == count


def test_trim_drops_surplus_questions_but_keeps_pages():
    blocks = [{"block_type": "page"}] + [{"block_type": "question"} for _ in range(12)]
    trimmed = _trim_questions(blocks, 10)
    assert sum(1 for b in trimmed if b["block_type"] == "question") == 10
    assert sum(1 for b in trimmed if b["block_type"] == "page") == 1


def test_count_by_type():
    assert _count_by_type([{"question_type": "single"}, {"question_type": "single"},
                           {"question_type": "fill"}]) == {"single": 2, "fill": 1}
