
import base64
import json
import time

import httpx

from app.utils.config import settings

GEMINI_MODELS = (
    "gemini-flash-lite-latest",
    "gemini-2.5-flash-lite",
    "gemini-3.5-flash",
)

GEMINI_MODEL = GEMINI_MODELS[0]


def _model_url(model: str) -> str:
    return f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

RETRYABLE_STATUS_CODES = {429, 500, 503, 504}
RETRY_DELAYS_SECONDS = (2, 5)

DEFAULT_TIMEOUT_SECONDS = 60.0


class GeminiError(Exception):
    pass


def text_part(text: str) -> dict:
    return {"text": text}


def image_part(image_bytes: bytes, mime_type: str) -> dict:
    return {
        "inline_data": {
            "mime_type": mime_type,
            "data": base64.b64encode(image_bytes).decode("ascii"),
        }
    }


def generate_json(
    parts: list[dict],
    response_schema: dict,
    timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS,
):
    if not settings.gemini_api_key:
        raise GeminiError("GEMINI_API_KEY is not configured")

    payload = {
        "contents": [{"parts": parts}],
        "generationConfig": {
            "responseMimeType": "application/json",
            "responseSchema": response_schema,
        },
    }

    response = None
    last_error: Exception | None = None
    with httpx.Client(timeout=timeout_seconds) as client:
        for model in GEMINI_MODELS:
            url = _model_url(model)
            for delay in (0, *RETRY_DELAYS_SECONDS):
                if delay:
                    time.sleep(delay)
                try:
                    response = client.post(
                        url,
                        params={"key": settings.gemini_api_key},
                        json=payload,
                    )
                except httpx.TimeoutException as exc:
                    last_error = exc
                    response = None
                    continue
                last_error = None
                if response.status_code == 200:
                    break
                if response.status_code not in RETRYABLE_STATUS_CODES:
                    break
            if response is not None and response.status_code == 200:
                break

    if response is None:
        raise GeminiError(f"Gemini API timed out after retries: {last_error}")

    if response.status_code != 200:
        raise GeminiError(f"Gemini API error {response.status_code}: {response.text[:800]}")

    data = response.json()
    try:
        text = data["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError) as exc:
        raise GeminiError("Gemini returned no readable content") from exc

    try:
        return json.loads(text)
    except ValueError as exc:
        raise GeminiError("Gemini response was not valid JSON") from exc
