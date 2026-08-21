"""One place that knows how to talk to Gemini.

Two features now call it -- reading a photographed journal page, and
generating lesson material -- and both need the same unglamorous parts: the
API key, a model that won't be deprecated out from under us, retries for
Google's transient rate limits, a timeout generous enough for a model that
"thinks" before answering, and JSON parsing that fails with a message a
human can act on. Written twice, those drift; the second copy is always the
one still using the old model name.
"""

import base64
import json
import time

import httpx

from app.utils.config import settings

# Tried in order. The moving alias comes first -- pinned ids get retired
# for newly issued keys and the first sign of it is a 404 in production --
# but an alias is also the busiest name on Google's shared capacity, and it
# answers 503 "high demand" for minutes at a time. When it does, a pinned
# current model almost always answers instantly, so falling through costs
# the teacher nothing and beats telling them to come back later.
#
# The lite model is last: fastest and least loaded, but weaker at the
# reasoning both callers need, so it's a backstop rather than a peer.
GEMINI_MODELS = (
    "gemini-flash-latest",
    "gemini-3.5-flash",
    "gemini-flash-lite-latest",
)

# Kept for callers that just want to report which model is configured.
GEMINI_MODEL = GEMINI_MODELS[0]


def _model_url(model: str) -> str:
    return f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

# Google's shared model capacity occasionally returns a transient 503
# ("high demand") or 429 (rate limit) that clears within seconds -- worth
# a couple of short retries before surfacing an error the teacher would
# otherwise have to fix by just tapping the button again.
RETRYABLE_STATUS_CODES = {429, 500, 503, 504}
RETRY_DELAYS_SECONDS = (2, 5)

# A photo, or a request to write a whole lesson, plus the reasoning these
# models do before answering, comfortably outruns a short timeout. 30s was
# too tight and turned a slow-but-fine response into an unhandled crash.
DEFAULT_TIMEOUT_SECONDS = 60.0


class GeminiError(Exception):
    """Anything that stopped us getting a usable answer. The message is
    surfaced to the caller, so it says what happened, not just 'error'."""


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
    """Send `parts`, insist on JSON shaped like `response_schema`, return it.

    Asking for a schema rather than parsing prose is what makes this usable
    from a server: the model returns the structure directly instead of a
    paragraph that has to be scraped, and a field it can't fill is simply
    absent rather than invented in a different format each time.
    """
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
                    # Caught rather than propagated: an uncaught timeout here
                    # turned into a 500 on an otherwise healthy request.
                    last_error = exc
                    response = None
                    continue
                last_error = None
                if response.status_code == 200:
                    break
                if response.status_code not in RETRYABLE_STATUS_CODES:
                    # A 404 means this model name is gone -- retrying it is
                    # pointless, but the next name in the list may well work.
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
