from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from typing import Any

from django.contrib.auth import get_user_model
from django.db import transaction

from lifelog.places.models import Place

from .models import Trip, TripNode


@dataclass
class RecommendationContext:
    time_budget_min: int = 90
    budget_min: int = 0
    budget_max: int = 0
    mode: str = Trip.Mode.WALK
    categories: list[str] | None = None
    tags: list[str] | None = None
    mood: list[str] | None = None
    district: str | None = None
    limit: int = 3
    skip_place_ids: list[str] | None = None


class NoPlacesAvailableError(Exception):
    """Raised when recommendation constraints cannot produce any places."""


def _prepare_context(data: dict[str, Any]) -> RecommendationContext:
    return RecommendationContext(
        time_budget_min=data.get("time_budget_min", 90),
        budget_min=data.get("budget_min", 0),
        budget_max=data.get("budget_max", 0),
        mode=data.get("mode", Trip.Mode.WALK),
        categories=[c.lower() for c in data.get("categories", []) if c],
        tags=[t.lower() for t in data.get("tags", []) if t],
        mood=[m.lower() for m in data.get("mood", []) if m],
        district=data.get("district") or None,
        limit=max(1, min(int(data.get("limit", 3)), 10)),
        skip_place_ids=data.get("skip_place_ids", []),
    )


def _build_context_hash(payload: dict[str, Any]) -> str:
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"))
    return hashlib.sha1(canonical.encode("utf-8")).hexdigest()


def _score_place(place: Place, ctx: RecommendationContext) -> float:
    base = float(place.rating or 0)
    if ctx.mood:
        mood_match = sum(place.mood_scores.get(m, 0) for m in ctx.mood)
        base += mood_match / max(len(ctx.mood), 1)
    if ctx.district and place.district == ctx.district:
        base += 0.2
    return base


def _select_places(ctx: RecommendationContext) -> list[Place]:
    qs = Place.objects.filter(is_active=True)

    if ctx.categories:
        qs = qs.filter(category__in=ctx.categories)
    if ctx.tags:
        qs = qs.filter(tags__name__in=ctx.tags)
    if ctx.district:
        qs = qs.filter(district__iexact=ctx.district)
    if ctx.skip_place_ids:
        qs = qs.exclude(id__in=ctx.skip_place_ids)

    qs = qs.distinct()

    candidates = list(qs)
    if not candidates:
        candidates = list(Place.objects.filter(is_active=True).exclude(id__in=ctx.skip_place_ids or []))

    if not candidates:
        raise NoPlacesAvailableError("no_places_available")

    scored = sorted(candidates, key=lambda place: _score_place(place, ctx), reverse=True)
    return scored[: ctx.limit]


@transaction.atomic
def create_recommendation(user_id: str | None, raw_constraints: dict[str, Any]) -> Trip:
    ctx = _prepare_context(raw_constraints)
    selected_places = _select_places(ctx)

    User = get_user_model()
    user = None
    if user_id:
        try:
            user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            user = None

    context_payload = {
        "user_id": str(user_id) if user_id else None,
        "constraints": raw_constraints,
    }
    context_hash = _build_context_hash(context_payload)

    duration = ctx.time_budget_min or 90
    per_stop = max(15, duration // max(len(selected_places), 1))

    title = selected_places[0].name if selected_places else "추천 코스"
    if len(selected_places) > 1:
        title = f"{title} 외 {len(selected_places) - 1}곳"

    trip = Trip.objects.create(
        owner=user,
        title=title,
        context_hash=context_hash,
        inputs=raw_constraints,
        duration_min=duration,
        budget_min=ctx.budget_min,
        budget_max=ctx.budget_max or ctx.budget_min,
        mode=ctx.mode,
        summary={
            "place_ids": [str(p.id) for p in selected_places],
            "categories": sorted({p.category for p in selected_places if p.category}),
            "tags": sorted({tag for p in selected_places for tag in p.tags.values_list("name", flat=True)}),
            "limit": ctx.limit,
        },
    )

    for sequence, place in enumerate(selected_places, start=1):
        TripNode.objects.create(
            trip=trip,
            place=place,
            sequence=sequence,
            planned_stay_min=per_stop,
            transition_mode=ctx.mode,
            notes={"selected_by": "recommendation"},
        )

    return trip
