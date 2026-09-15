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
        raise JournalScanError(str(exc)) from exc

    if not isinstance(parsed, list):
        raise JournalScanError("Gemini response was not a list")
    return parsed


def _best_match(raw_name: str, roster: list[tuple[int, str]]) -> tuple[int | None, str | None, float]:
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
