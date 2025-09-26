from __future__ import annotations

import json
import math
import textwrap
from typing import Any, Dict, List

from django.utils.text import slugify

from lifelog.places.models import Place

SYSTEM_PROMPT = textwrap.dedent(
    """
    You are an expert travel concierge creating concise mobile-friendly trip templates for urban explorers in Korea.
    Always respond with a single JSON object that follows this schema:
    {
      "title": string (max 80 chars),
      "summary": string (max 160 chars),
      "duration_min": integer (estimated total minutes for the trip),
      "mood_tags": list[string],
      "stops": [
        {
          "name": string,
          "description": string (max 140 chars, user-facing copy),
          "stay_min": integer (minutes to spend),
          "category": string (optional quick label like cafe, gallery, park),
          "address": string (optional plain address),
          "tip": string (optional insider or etiquette tip)
        }
      ],
      "tips": string (optional general guidance for the whole course)
    }
    Rules:
    - Produce between 2 and 4 stops unless explicitly specified otherwise.
    - The JSON must be strictly valid and shall not include Markdown, lists, or additional commentary.
    - Prefer spots that match the user's brief while keeping variety in activities and atmosphere.
    - Titles should be warm and brandable; summaries should explain why the course matters in one sentence.
    - stay_min should be at least 20 minutes unless the user requests very short visits.
    - Omit fields instead of returning null when information is unknown.
    """
)


def build_messages(prompt: dict[str, Any]) -> List[dict[str, str]]:
    user_payload: Dict[str, Any] = {
        "brief": prompt.get("brief", "").strip(),
        "location": prompt.get("location", "").strip(),
        "mood_tags": prompt.get("mood_tags", []),
        "avoid": prompt.get("avoid", []),
        "duration_min": int(prompt.get("duration_min", 0) or 0),
        "stops": int(prompt.get("stops", 0) or 0),
        "budget_level": prompt.get("budget_level"),
        "time_of_day": prompt.get("time_of_day"),
        "audience": prompt.get("audience"),
        "additional_notes": prompt.get("additional_notes"),
    }

    return [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": json.dumps(user_payload, ensure_ascii=False)},
    ]


def _clean_text(value: Any, *, fallback: str = "") -> str:
    if not value:
        return fallback
    text = str(value).strip()
    return text or fallback


def _clean_int(value: Any, *, fallback: int = 0, minimum: int | None = None, maximum: int | None = None) -> int:
    try:
        number = int(math.floor(float(value)))
    except (TypeError, ValueError):
        number = fallback
    if minimum is not None and number < minimum:
        number = minimum
    if maximum is not None and number > maximum:
        number = maximum
    return number


def _clean_list(values: Any) -> list[str]:
    items: list[str] = []
    if isinstance(values, (list, tuple, set)):
        for item in values:
            text = _clean_text(item)
            if text:
                items.append(text[:40])
    return items


def normalize_template_payload(payload: dict[str, Any]) -> dict[str, Any]:
    title = _clean_text(payload.get("title"), fallback="AI Trip Course")[:80]
    summary = _clean_text(payload.get("summary"), fallback="감성 가득한 하루를 위한 코스")[:180]
    duration_min = _clean_int(payload.get("duration_min"), fallback=180, minimum=45, maximum=720)
    mood_tags = _clean_list(payload.get("mood_tags"))[:6]

    stops_raw = payload.get("stops") or []
    normalized_stops: list[dict[str, Any]] = []

    for item in stops_raw:
        if not isinstance(item, dict):
            continue
        name = _clean_text(item.get("name"))
        if not name:
            continue
        stop = {
            "name": name[:80],
            "description": _clean_text(item.get("description"))[:180],
            "stay_min": _clean_int(item.get("stay_min"), fallback=45, minimum=20, maximum=240),
        }
        category = _clean_text(item.get("category"))
        if category:
            stop["category"] = category[:40]
        address = _clean_text(item.get("address"))
        if address:
            stop["address"] = address[:120]
        tip = _clean_text(item.get("tip"))
        if tip:
            stop["tip"] = tip[:160]
        normalized_stops.append(stop)

    if not normalized_stops:
        # Provide a placeholder stop to avoid empty itineraries.
        normalized_stops.append(
            {
                "name": "현지 카페 추천",
                "description": "아늑한 분위기의 카페에서 여유롭게 시작해 보세요.",
                "stay_min": 45,
                "tip": "사전에 예약 가능한지 확인하면 좋아요.",
            }
        )

    tips = _clean_text(payload.get("tips"))[:220]
    if tips:
        general_tips = tips
    else:
        general_tips = "여유 있게 이동하며 각 공간의 분위기를 온전히 느껴보세요."

    result = {
        "title": title,
        "summary": summary,
        "duration_min": duration_min,
        "mood_tags": mood_tags,
        "stops": normalized_stops,
        "tips": general_tips,
        "slug": slugify(title)[:140] or slugify(summary)[:140],
    }

    _attach_existing_place_ids(normalized_stops)
    return result


def _attach_existing_place_ids(stops: list[dict[str, Any]]) -> None:
    for stop in stops:
        name = stop.get("name")
        if not name:
            continue
        place = Place.objects.filter(name__iexact=name).first()
        if place:
            stop["place_id"] = str(place.id)
            slug = getattr(place, "slug", "")
            if slug:
                stop["place_slug"] = slug

