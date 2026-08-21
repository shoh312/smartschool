import difflib
from datetime import date

from app.services.gemini_client import GeminiError, generate_json, image_part, text_part

_RESPONSE_SCHEMA = {
    "type": "ARRAY",
    "items": {
        "type": "OBJECT",
        "properties": {
            "name": {"type": "STRING"},
            "status": {"type": "STRING", "enum": ["graded", "absent"]},
            "grade": {"type": "INTEGER"},
        },
        "required": ["name", "status"],
    },
}


def _build_prompt(target_day: int) -> str:
    # Journal date headers are a single day-of-month number (1-31) repeated
    # across several months on the same page -- naming the exact number
    # up front, instead of the previous "rightmost filled column" guess,
    # is what stops Gemini from drifting onto a neighboring column when a
    # handwritten header is ambiguous.
    return (
        "Bu maktab jurnalining bir sahifasi surati. Jadvalning har bir "
        "qatorida bitta o'quvchining ism-familiyasi, ustida esa har bir "
        f"ustun sarlavhasida kun raqami (1 dan 31 gacha) yozilgan. FAQAT "
        f"sarlavhasi aynan {target_day} raqamiga teng bo'lgan BITTA ustunni "
        "top va shu ustundagi qatorlarni o'qi -- boshqa hech qanday "
        "ustunga qarama, hattoki u to'liqroq to'ldirilgan bo'lsa ham. "
        "Har bir qator uchun uchta narsa aniqla: "
        "1) 'name' -- o'quvchining ism-familiyasi (jurnalda yozilganidek); "
        "2) 'status' -- agar shu ustunda oddiy baho raqami (odatda 1-10 "
        "oralig'ida) yozilgan bo'lsa 'graded', agar o'rniga kelmaganlik "
        "belgisi bo'lsa (masalan 'н', 'нб', chiziqcha, X yoki shunga "
        "o'xshash, RAQAM EMAS) 'absent'; "
        "3) 'grade' -- faqat status='graded' bo'lsa shu ustundagi son, "
        "aks holda bu maydonni qo'shma. "
        "Agar biror o'quvchining shu ustunidagi katakchasi butunlay bo'sh "
        "bo'lsa (na baho, na kelmaganlik belgisi), o'sha o'quvchini "
        "ro'yxatga UMUMAN QO'SHMA -- taxmin qilib hech narsa to'ldirma."
    )


class JournalScanError(Exception):
    pass


def _call_gemini(image_bytes: bytes, mime_type: str, target_day: int) -> list[dict]:
    try:
        parsed = generate_json(
            [text_part(_build_prompt(target_day)), image_part(image_bytes, mime_type)],
            _RESPONSE_SCHEMA,
        )
    except GeminiError as exc:
        # Re-raised under this feature's own error type so callers keep
        # catching JournalScanError and nothing above here has to learn
        # about the transport.
        raise JournalScanError(str(exc)) from exc

    if not isinstance(parsed, list):
        raise JournalScanError("Gemini response was not a list")
    return parsed


def _best_match(raw_name: str, roster: list[tuple[int, str]]) -> tuple[int | None, str | None, float]:
    """Fuzzy-matches an OCR'd name against the class roster. No new
    dependency (rapidfuzz) needed -- stdlib difflib is good enough for
    "one typo in a short name" scale matching against a roster of ~30 names.

    A class often has two students sharing a surname (e.g. "Юсупова Н" and
    "Юсупова Ш"), differing only by the initial -- an OCR misread of that
    one letter can tip a plain top-1 pick to the wrong sibling. When the
    runner-up is nearly as good a match as the winner, the reported
    confidence is capped low so the UI flags the row instead of silently
    presenting a coin-flip as a sure thing.
    """
    best_id: int | None = None
    best_name: str | None = None
    best_ratio = 0.0
    second_ratio = 0.0
    for student_id, full_name in roster:
        ratio = difflib.SequenceMatcher(None, raw_name.lower(), full_name.lower()).ratio()
        if ratio > best_ratio:
            second_ratio = best_ratio
            best_ratio = ratio
            best_id = student_id
            best_name = full_name
        elif ratio > second_ratio:
            second_ratio = ratio

    confidence = best_ratio
    if best_ratio > 0 and (best_ratio - second_ratio) < 0.08:
        confidence = min(confidence, 0.5)
    return best_id, best_name, confidence


def scan_journal_photo(
    image_bytes: bytes,
    mime_type: str,
    roster: list[tuple[int, str]],
    target_day: int | None = None,
) -> list[dict]:
    """Reads a journal-page photo via Gemini vision and matches each
    detected row onto the class roster. Returns candidates only -- callers
    still need to review/confirm before actually writing grades.

    Each result is either a real grade ("absent": False, "grade": int) or an
    absence mark read straight off the page ("absent": True, "grade": None)
    -- never a guessed number standing in for either.
    """
    raw_rows = _call_gemini(image_bytes, mime_type, target_day or date.today().day)

    results = []
    for row in raw_rows:
        raw_name = str(row.get("name", "")).strip()
        if not raw_name:
            continue
        status = row.get("status")
        absent = status == "absent"
        grade = row.get("grade")
        if not absent and not isinstance(grade, int):
            # Neither a real grade nor a recognized absence mark -- most
            # likely a misread of a blank cell. Skip rather than guess.
            continue

        student_id, matched_name, confidence = _best_match(raw_name, roster)
        results.append(
            {
                "raw_name": raw_name,
                "student_id": student_id,
                "matched_name": matched_name,
                "confidence": round(confidence, 2),
                "absent": absent,
                "grade": None if absent else grade,
            }
        )
    return results
