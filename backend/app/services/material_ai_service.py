"""Drafting lesson material with Gemini.

The teacher gives a starting point -- a topic, a photograph of a textbook
page, or text pasted from wherever they already keep it -- and this returns
the same block list the editor and the paste importer produce. Nothing is
saved: the teacher reviews and edits every block before any of it becomes a
material, because a model that is mostly right about quadratic equations is
still occasionally confidently wrong, and this ends up in front of children.

The two things that make the output usable rather than a wall of prose:

* a ``responseSchema``, so Gemini answers in the block structure directly;
* a validation pass, which holds every block to the same rules the editor
  enforces and drops what can't be repaired -- a question with no correct
  answer can never be answered right, and the pupil only finds that out at
  the end of the test.
"""

import re

from app.services.gemini_client import GeminiError, generate_json, image_part, text_part

# Mirrors app/models/material_model.py; kept as plain strings so the prompt
# and the schema can't drift from the model's own vocabulary.
QUESTION_TYPES = ("single", "truefalse", "fill", "match", "order")

DIFFICULTIES = ("easy", "medium", "hard")

MAX_QUESTIONS = 25
MAX_PAGES = 12


class MaterialAiError(Exception):
    pass


_RESPONSE_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "title": {"type": "STRING"},
        "description": {"type": "STRING"},
        "blocks": {
            "type": "ARRAY",
            "items": {
                "type": "OBJECT",
                "properties": {
                    "block_type": {"type": "STRING", "enum": ["page", "question"]},
                    "body": {"type": "STRING"},
                    "question_type": {"type": "STRING", "enum": list(QUESTION_TYPES)},
                    # Two fields, both plain, for every question type.
                    #
                    # There used to be seven (single_options,
                    # single_correct_index, truefalse_answer, fill_answers,
                    # match_left, match_right, order_items) and the model
                    # could not keep them straight: it stamped
                    # truefalse_answer on *every* question and left the
                    # type's own field empty, so roughly half of what it
                    # produced was unanswerable and got dropped. Fewer
                    # slots, and no per-type choice to get wrong.
                    "options": {"type": "ARRAY", "items": {"type": "STRING"}},
                    "answer": {"type": "STRING"},
                },
                "required": ["block_type", "body"],
            },
        },
    },
    "required": ["title", "blocks"],
}


_TYPE_DESCRIPTIONS = {
    "single": (
        "single -- bitta to'g'ri javobli savol. 'options' ga 4 ta variant yoz, "
        "'answer' ga to'g'ri variantning MATNINI aynan ko'chirib yoz "
        "(raqam emas, aynan o'sha matn)."
    ),
    "truefalse": (
        "truefalse -- to'g'ri/noto'g'ri savoli. 'options' ni bo'sh qoldir, "
        "'answer' ga faqat 'true' yoki 'false' deb yoz."
    ),
    "fill": (
        "fill -- o'quvchi javobni yozadigan savol. 'options' ni bo'sh qoldir, "
        "'answer' ga to'g'ri javobni yoz; bir nechta imlo varianti bo'lsa "
        "ularni | belgisi bilan ajrat, masalan: 10|dah."
    ),
    "match": (
        "match -- juftlash. 'options' ning har bir qatoriga bitta juftlikni "
        "'chap = o'ng' ko'rinishida yoz, masalan: 'Suръat = m/s'. Kamida 3 ta "
        "juftlik bo'lsin. 'answer' ni bo'sh qoldir."
    ),
    "order": (
        "order -- tartiblash. 'options' ga elementlarni TO'G'RI tartibda yoz "
        "(o'quvchiga ular aralashtirilib ko'rsatiladi). 'answer' ni bo'sh qoldir."
    ),
}


_DIFFICULTY_HINTS = {
    "easy": "Savollar oson bo'lsin: asosiy ta'rif va oddiy misollar.",
    "medium": "Savollar o'rtacha qiyinlikda bo'lsin.",
    "hard": "Savollar qiyin bo'lsin: bir necha qadamli masalalar va chuqurroq tushunish talab qilsin.",
}


def _distribute(question_count: int, types: list[str]) -> dict[str, int]:
    """How many questions of each selected type.

    Asking for "use these types" produced almost nothing but true/false:
    given a free choice the model reaches for the cheapest question to
    write. Handing it an explicit quota per type is what actually spreads
    them out. The remainder goes to the types the teacher listed first,
    which are the ones they picked most deliberately.
    """
    base, remainder = divmod(question_count, len(types))
    return {
        question_type: base + (1 if index < remainder else 0)
        for index, question_type in enumerate(types)
    }


def _build_prompt(
    *,
    subject: str,
    topic: str | None,
    source_text: str | None,
    has_image: bool,
    class_name: str | None,
    kind: str,
    question_count: int,
    page_count: int,
    question_types: list[str],
    difficulty: str,
    language: str,
) -> str:
    if has_image:
        source = (
            "Manba -- biriktirilgan darslik sahifasining surati. Uni o'qi va "
            "AYNAN shu sahifadagi mavzu bo'yicha material tayyorla."
        )
    elif source_text:
        source = (
            "Manba -- quyidagi matn. Uni qayta yozib, sahifa va savollarga ajrat:\n\n"
            f"---\n{source_text.strip()[:8000]}\n---"
        )
    else:
        source = f"Mavzu: {topic}"

    quota = _distribute(question_count, question_types)
    wanted_types = ", ".join(f"{t} -- {n} ta" for t, n in quota.items())
    type_rules = "\n".join(f"- {_TYPE_DESCRIPTIONS[t]}" for t in question_types)

    if kind == "test":
        structure = (
            f"Faqat {question_count} ta savol yoz. Tushuntirish sahifasi (page) "
            "QO'SHMA."
        )
    else:
        structure = (
            f"{page_count} ta tushuntirish sahifasi (block_type='page') va "
            f"{question_count} ta savol (block_type='question') yoz. Ularni "
            "ARALASHTIRIB joylashtir: avval bir sahifa tushuntirish, keyin shu "
            "sahifaga oid 1-2 savol, keyin yana sahifa -- shu tartibda."
        )

    return (
        f"Sen tajribali {subject} o'qituvchisisan"
        + (f" va bu material {class_name} sinfi uchun." if class_name else ".")
        + f"\n\n{source}\n\n"
        f"Vazifa: {structure}\n\n"
        # A bare list of allowed types produced almost nothing but
        # true/false; a quota per type is what actually spreads them.
        f"Savol turlari AYNAN shunday taqsimlansin (majburiy): {wanted_types}.\n"
        f"{type_rules}\n\n"
        f"{_DIFFICULTY_HINTS.get(difficulty, '')}\n\n"
        "Qoidalar:\n"
        f"- Hamma matn {language} tilida bo'lsin.\n"
        "- Sahifa matni qisqa va tushunarli bo'lsin: 3-6 jumla, bir sahifada bitta fikr.\n"
        "- Har bir savolning javobi manbadagi yoki sahifalarda tushuntirilgan "
        "ma'lumotdan kelib chiqsin -- sahifalarda yo'q narsani so'rama.\n"
        "- Faktlarga ehtiyot bo'l: sana, formula va ta'riflarda aniq bo'l. "
        "Ishonching komil bo'lmagan faktni umuman yozma.\n"
        "- 'title' ga materialning qisqa nomini, 'description' ga bir jumlalik "
        "izohini yoz.\n"
        "- Savol matnida javobning o'zi yozilib qolmasin.\n"
        # The app renders plain text, so LaTeX arrives on the pupil's screen
        # as literal backslashes and braces.
        "- Formulalarni ODDIY MATN bilan yoz: a^2 + b^2 = c^2, sqrt(16), 1/2. "
        "LaTeX belgilarini ishlatma.\n"
        f"- AYNAN {question_count} ta savol bo'lsin -- kam ham, ko'p ham emas."
    )


# --------------------------------------------------------------------------
# Validation
# --------------------------------------------------------------------------

def _clean(value) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


def _fold(value: str) -> str:
    """Loosest sensible comparison for "is this the same answer".

    The model routinely writes the correct option back as "5." or "5)" when
    the option itself is "5"; letting a trailing full stop throw away an
    otherwise perfect question would be absurd.
    """
    text = re.sub(r"[.,;:!?)\]}\s]+$", "", value.strip())
    return re.sub(r"\s+", " ", text).casefold()


def _clean_list(values) -> list[str]:
    if not isinstance(values, list):
        return []
    return [text for text in (_clean(v) for v in values) if text]


def _validate_block(raw: dict) -> dict | None:
    """Turn one raw block into an editor-shaped one, or None to drop it.

    Dropping is deliberate. Everything here is a case where the block cannot
    be answered correctly no matter what the pupil does -- a matching
    question with four items on the left and three on the right, a
    multiple-choice question whose correct index points past the end of the
    options. Handing those to the teacher as something to "fix" is worse
    than not offering them: the fault isn't visible until someone sits the
    test.
    """
    if not isinstance(raw, dict):
        return None

    body = _clean(raw.get("body"))
    if not body:
        return None

    if raw.get("block_type") == "page":
        # Pages keep their paragraph breaks; only questions are collapsed
        # to a single line.
        return {"block_type": "page", "body": str(raw.get("body")).strip(), "points": 0}

    question_type = raw.get("question_type")
    if question_type not in QUESTION_TYPES:
        return None

    block = {"block_type": "question", "body": body, "question_type": question_type, "points": 1}

    options = _clean_list(raw.get("options"))
    answer = _clean(raw.get("answer"))

    if question_type == "single":
        if len(options) < 2 or not answer:
            return None
        if len(set(options)) != len(options):
            return None  # a duplicated option means two "correct" answers
        # Matched by text, not by an index the model kept forgetting to
        # send. A near-miss on spacing or a trailing full stop shouldn't
        # cost a whole question, so compare loosely.
        folded = [_fold(o) for o in options]
        try:
            index = folded.index(_fold(answer))
        except ValueError:
            return None
        block["options"] = options
        block["correct"] = {"index": index}

    elif question_type == "truefalse":
        truthy = {"true", "ha", "to'g'ri", "togri", "дуруст", "ҳа"}
        falsy = {"false", "yo'q", "yoq", "noto'g'ri", "нодуруст", "не"}
        folded = answer.casefold()
        if folded in truthy:
            value = True
        elif folded in falsy:
            value = False
        else:
            return None
        block["options"] = None
        block["correct"] = {"value": value}

    elif question_type == "fill":
        answers = [part for part in (_clean(a) for a in answer.split("|")) if part]
        if not answers:
            return None
        block["options"] = None
        block["correct"] = {"answers": answers}

    elif question_type == "match":
        # Each option is one "left = right" pair, so the two sides can't
        # come back different lengths the way two separate lists did.
        left: list[str] = []
        right: list[str] = []
        for option in options:
            if "=" not in option:
                continue
            a, b = option.split("=", 1)
            a, b = _clean(a), _clean(b)
            if a and b:
                left.append(a)
                right.append(b)
        if len(left) < 2:
            return None
        block["options"] = {"left": left, "right": right}
        # Authored in matching order, same convention as the editor.
        block["correct"] = {"pairs": [[i, i] for i in range(len(left))]}

    elif question_type == "order":
        if len(options) < 2:
            return None
        block["options"] = options
        block["correct"] = {"order": list(range(len(options)))}

    return block


def _validate(parsed: dict, kind: str) -> dict:
    if not isinstance(parsed, dict):
        raise MaterialAiError("Gemini javobi kutilgan ko'rinishda emas")

    raw_blocks = parsed.get("blocks")
    if not isinstance(raw_blocks, list) or not raw_blocks:
        raise MaterialAiError("Gemini birorta blok qaytarmadi")

    blocks = []
    dropped = 0
    for raw in raw_blocks:
        block = _validate_block(raw)
        if block is None:
            dropped += 1
            continue
        if kind == "test" and block["block_type"] == "page":
            continue
        blocks.append(block)

    if not any(b["block_type"] == "question" for b in blocks):
        raise MaterialAiError("Gemini yaroqli savol qaytarmadi, qaytadan urinib ko'ring")

    for position, block in enumerate(blocks):
        block["position"] = position

    return {
        "title": _clean(parsed.get("title")) or "",
        "description": _clean(parsed.get("description")) or None,
        "blocks": blocks,
        # Surfaced so the teacher is told when the model produced fewer
        # questions than they asked for, instead of quietly getting six
        # when they wanted ten.
        "dropped_count": dropped,
    }


# --------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------

def generate_material(
    *,
    subject: str,
    kind: str = "lesson",
    topic: str | None = None,
    source_text: str | None = None,
    image_bytes: bytes | None = None,
    image_mime: str | None = None,
    class_name: str | None = None,
    question_count: int = 8,
    page_count: int = 3,
    question_types: list[str] | None = None,
    difficulty: str = "medium",
    language: str = "tojik (kirill)",
) -> dict:
    """Draft a material. Returns ``{title, description, blocks, dropped_count}``."""
    if not (topic or source_text or image_bytes):
        raise MaterialAiError("Mavzu, matn yoki surat kerak")

    types = [t for t in (question_types or []) if t in QUESTION_TYPES] or ["single"]
    kind = "test" if kind == "test" else "lesson"
    question_count = max(1, min(question_count, MAX_QUESTIONS))
    page_count = 0 if kind == "test" else max(1, min(page_count, MAX_PAGES))
    difficulty = difficulty if difficulty in DIFFICULTIES else "medium"

    prompt = _build_prompt(
        subject=subject,
        topic=topic,
        source_text=source_text,
        has_image=image_bytes is not None,
        class_name=class_name,
        kind=kind,
        question_count=question_count,
        page_count=page_count,
        question_types=types,
        difficulty=difficulty,
        language=language,
    )

    def call(prompt_text: str) -> dict:
        parts = [text_part(prompt_text)]
        if image_bytes is not None:
            parts.append(image_part(image_bytes, image_mime or "image/jpeg"))
        try:
            return generate_json(parts, _RESPONSE_SCHEMA)
        except GeminiError as exc:
            raise MaterialAiError(str(exc)) from exc

    try:
        result = _validate(call(prompt), kind)
    except MaterialAiError:
        # Everything it produced was unanswerable -- in practice this means
        # it filled the wrong answer field for the question type it chose.
        # One more attempt, with the field names spelled out again, beats
        # handing the teacher an error for something a retry usually fixes.
        result = _validate(
            call(
                prompt
                + "\n\nDIQQAT: oldingi javobda savollarning javob maydonlari "
                "noto'g'ri to'ldirilgan edi. Har bir savol uchun AYNAN o'z "
                "turiga tegishli maydonlarni to'ldir va ularsiz savol yozma."
            ),
            kind,
        )

    # The count the teacher asked for is a promise, and until now it wasn't
    # kept: the model tends to write a few short, and validation then drops
    # any that came back unanswerable, so "10" arrived as six or seven. Ask
    # once more for exactly the shortfall and append what comes back.
    questions = [b for b in result["blocks"] if b["block_type"] == "question"]
    missing = question_count - len(questions)
    if missing > 0:
        have = _count_by_type(questions)
        wanted = _distribute(question_count, types)
        short = {t: wanted[t] - have.get(t, 0) for t in types if wanted[t] - have.get(t, 0) > 0}
        try:
            extra = _validate(call(_top_up_prompt(prompt, missing, short)), "test")
        except MaterialAiError:
            extra = {"blocks": [], "dropped_count": 0}

        for block in extra["blocks"]:
            if block["block_type"] != "question" or missing <= 0:
                continue
            result["blocks"].append(block)
            missing -= 1
        result["dropped_count"] += extra["dropped_count"]

    # And trim if it overshot, so "exactly N" holds in both directions.
    result["blocks"] = _trim_questions(result["blocks"], question_count)
    for position, block in enumerate(result["blocks"]):
        block["position"] = position

    return result


def _count_by_type(questions: list[dict]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for block in questions:
        key = block.get("question_type") or ""
        counts[key] = counts.get(key, 0) + 1
    return counts


def _top_up_prompt(base_prompt: str, missing: int, short: dict[str, int]) -> str:
    wanted = ", ".join(f"{t} -- {n} ta" for t, n in short.items()) or f"{missing} ta"
    return (
        base_prompt
        + f"\n\nDIQQAT: endi FAQAT {missing} ta QO'SHIMCHA savol yoz. "
        f"Tushuntirish sahifasi (page) QO'SHMA. Turlari: {wanted}. "
        "Oldin yozilgan savollarni takrorlama, yangi savollar yoz."
    )


def _trim_questions(blocks: list[dict], limit: int) -> list[dict]:
    """Keep at most `limit` questions, dropping the last ones.

    Trimming from the end rather than anywhere keeps a lesson's opening
    pages and their questions intact; what goes is the tail the model added
    beyond what was asked for.
    """
    kept: list[dict] = []
    seen = 0
    for block in blocks:
        if block["block_type"] == "question":
            if seen >= limit:
                continue
            seen += 1
        kept.append(block)
    return kept
