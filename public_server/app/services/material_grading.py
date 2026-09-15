
import re
import unicodedata

Q_SINGLE = "single"
Q_TRUEFALSE = "truefalse"
Q_FILL = "fill"
Q_MATCH = "match"
Q_ORDER = "order"


def _normalise_text(value: str) -> str:
    text = unicodedata.normalize("NFKC", value).strip().casefold()
    text = re.sub(r"[.,!?;:\"'`´’()\[\]{}]+", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def _grade_single(correct: dict, answer: dict) -> bool:
    if not isinstance(answer, dict) or "index" not in answer:
        return False
    try:
        return int(answer["index"]) == int(correct.get("index", -1))
    except (TypeError, ValueError):
        return False


def _grade_truefalse(correct: dict, answer: dict) -> bool:
    if not isinstance(answer, dict) or "value" not in answer:
        return False
    return bool(answer["value"]) is bool(correct.get("value"))


def _grade_fill(correct: dict, answer: dict) -> bool:
    if not isinstance(answer, dict):
        return False
    given = _normalise_text(str(answer.get("text", "")))
    if not given:
        return False
    accepted = correct.get("answers") or []
    return any(given == _normalise_text(str(item)) for item in accepted)


def _grade_match(correct: dict, answer: dict) -> bool:
    if not isinstance(answer, dict):
        return False
    try:
        given = {(int(a), int(b)) for a, b in (answer.get("pairs") or [])}
        wanted = {(int(a), int(b)) for a, b in (correct.get("pairs") or [])}
    except (TypeError, ValueError):
        return False
    return bool(wanted) and given == wanted


def _grade_order(correct: dict, answer: dict) -> bool:
    if not isinstance(answer, dict):
        return False
    try:
        given = [int(i) for i in (answer.get("order") or [])]
        wanted = [int(i) for i in (correct.get("order") or [])]
    except (TypeError, ValueError):
        return False
    return bool(wanted) and given == wanted


_GRADERS = {
    Q_SINGLE: _grade_single,
    Q_TRUEFALSE: _grade_truefalse,
    Q_FILL: _grade_fill,
    Q_MATCH: _grade_match,
    Q_ORDER: _grade_order,
}


def is_answer_correct(question_type: str, correct, answer) -> bool:
    grader = _GRADERS.get(question_type or "")
    if grader is None or not isinstance(correct, dict):
        return False
    return grader(correct, answer)


def score_attempt(blocks, answers) -> tuple[int, int]:
    score = 0
    max_score = 0
    lookup = {str(key): value for key, value in (answers or {}).items()}
    for block in blocks:
        points = block.points or 0
        max_score += points
        if is_answer_correct(block.question_type, block.correct, lookup.get(str(block.id))):
            score += points
    return score, max_score


def suggest_grade(percent: int | None) -> int | None:
    if percent is None:
        return None
    if percent >= 90:
        return 5
    if percent >= 75:
        return 4
    if percent >= 55:
        return 3
    return 2


_QUESTION_START = re.compile(r"^\s*(\d+)\s*[.)]\s*(.*)$")
_PAGE_START = re.compile(r"^\s*#\s*(.*)$")
_CORRECT_OPTION = re.compile(r"^\s*\*\s*(.+)$")
_WRONG_OPTION = re.compile(r"^\s*-\s*(.+)$")
_FILL_ANSWER = re.compile(r"^\s*=\s*(.+)$")


class PasteImportError(ValueError):
    pass


def parse_pasted_blocks(text: str) -> list[dict]:
    blocks: list[dict] = []
    current: dict | None = None

    def flush() -> None:
        nonlocal current
        if current is None:
            return
        if current["block_type"] == "question":
            _finalise_question(current)
        elif not (current["body"] or "").strip():
            current = None
            return
        blocks.append(current)
        current = None

    for line_no, raw_line in enumerate(text.splitlines(), start=1):
        line = raw_line.rstrip()

        page = _PAGE_START.match(line)
        if page:
            flush()
            current = {"block_type": "page", "body": page.group(1).strip()}
            continue

        question = _QUESTION_START.match(line)
        if question:
            flush()
            current = {
                "block_type": "question",
                "body": question.group(2).strip(),
                "question_type": Q_SINGLE,
                "_options": [],
                "_correct_indexes": [],
                "_fill": [],
                "_line": line_no,
            }
            continue

        if current is None:
            if line.strip():
                raise PasteImportError(
                    f"{line_no}-qator: bu matn qaysi savolga tegishli ekani "
                    f"aniq emas. Savolni «1.» kabi raqam bilan boshlang yoki "
                    f"sahifa uchun «#» qo'ying."
                )
            continue

        if current["block_type"] == "page":
            if not line.strip():
                flush()
            else:
                current["body"] = f"{current['body']}\n{line.strip()}".strip()
            continue

        fill = _FILL_ANSWER.match(line)
        if fill:
            current["_fill"].append(fill.group(1).strip())
            continue

        correct_option = _CORRECT_OPTION.match(line)
        if correct_option:
            current["_correct_indexes"].append(len(current["_options"]))
            current["_options"].append(correct_option.group(1).strip())
            continue

        wrong_option = _WRONG_OPTION.match(line)
        if wrong_option:
            current["_options"].append(wrong_option.group(1).strip())
            continue

        if not line.strip():
            flush()
            continue

        current["body"] = f"{current['body']} {line.strip()}".strip()

    flush()

    if not blocks:
        raise PasteImportError(
            "Matndan birorta savol topilmadi. Har bir savolni «1.» kabi "
            "raqam bilan boshlang."
        )
    for position, block in enumerate(blocks):
        block["position"] = position
    return blocks


def _finalise_question(block: dict) -> None:
    line_no = block.pop("_line", 0)
    options = block.pop("_options")
    correct_indexes = block.pop("_correct_indexes")
    fill_answers = block.pop("_fill")

    if not block["body"]:
        raise PasteImportError(f"{line_no}-qator: savol matni bo'sh.")

    if fill_answers:
        if options:
            raise PasteImportError(
                f"{line_no}-qator: bir savolda ham variantlar, ham «=» javob "
                f"bo'lishi mumkin emas."
            )
        block["question_type"] = Q_FILL
        block["options"] = None
        block["correct"] = {"answers": fill_answers}
    elif options:
        if len(options) < 2:
            raise PasteImportError(
                f"{line_no}-qator: kamida 2 ta variant kerak."
            )
        if len(correct_indexes) != 1:
            raise PasteImportError(
                f"{line_no}-qator: to'g'ri javob «*» bilan aynan bitta "
                f"variantda belgilanishi kerak."
            )
        block["question_type"] = Q_SINGLE
        block["options"] = options
        block["correct"] = {"index": correct_indexes[0]}
    else:
        raise PasteImportError(
            f"{line_no}-qator: savolga variant («*», «-») yoki javob («=») "
            f"qo'shilmagan."
        )

    block["points"] = 1
