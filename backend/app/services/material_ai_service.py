
import re

from app.services.gemini_client import GeminiError, generate_json, image_part, text_part

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
                    "options": {"type": "ARRAY", "items": {"type": "STRING"}},
                    "answer": {"type": "STRING"},
                },
                "required": ["block_type", "body", "options", "answer"],
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
        "- Formulalarni ODDIY MATN bilan yoz: a^2 + b^2 = c^2, sqrt(16), 1/2. "
        "LaTeX belgilarini ishlatma.\n"
        f"- AYNAN {question_count} ta savol bo'lsin -- kam ham, ko'p ham emas."
    )


def _clean(value) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


def _fold(value: str) -> str:
    text = re.sub(r"[.,;:!?)\]}\s]+$", "", value.strip())
    return re.sub(r"\s+", " ", text).casefold()


def _clean_list(values) -> list[str]:
    if not isinstance(values, list):
        return []
    return [text for text in (_clean(v) for v in values) if text]


def _validate_block(raw: dict) -> dict | None:
    if not isinstance(raw, dict):
        return None

    body = _clean(raw.get("body"))
    if not body:
        return None

    if raw.get("block_type") == "page":
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
            return None
        folded = [_fold(o) for o in options]
        fa = _fold(answer)
        raw_answer = answer.strip()
        index = None
        if fa in folded:                                   # exact option text
            index = folded.index(fa)
        elif len(raw_answer) == 1 and raw_answer.upper() in "ABCDEFGHIJ":  # "B"
            i = ord(raw_answer.upper()) - 65
            index = i if 0 <= i < len(options) else None
        elif raw_answer.isdigit():                          # "2" (1-based)
            i = int(raw_answer) - 1
            index = i if 0 <= i < len(options) else None
        else:                                               # paraphrase / contains
            for k, o in enumerate(folded):
                if fa and o and (fa in o or o in fa):
                    index = k
                    break
        if index is None:
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
        "dropped_count": dropped,
    }


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

    # Gemini occasionally returns questions with the wrong answer fields, which
    # `_validate` rejects. Try a few times, nudging harder each round, so a bad
    # roll of the dice never reaches the teacher as an error.
    hint = ("\n\nDIQQAT: oldingi javобда савولларнинг жавоб майдонлари "
            "нотўғри тўлдирилган эди. Ҳар бир савол учун АЙНАН ўз турига "
            "тегишли майдонларни тўлдир ва уларсиз савол ёзма.")
    result = None
    last_err: MaterialAiError | None = None
    for attempt in range(3):
        try:
            result = _validate(call(prompt + (hint if attempt else "")), kind)
            break
        except MaterialAiError as exc:
            last_err = exc
    if result is None:
        raise last_err or MaterialAiError("Gemini yaroqli savol qaytarmadi, qaytadan urinib ko'ring")

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
    kept: list[dict] = []
    seen = 0
    for block in blocks:
        if block["block_type"] == "question":
            if seen >= limit:
                continue
            seen += 1
        kept.append(block)
    return kept
