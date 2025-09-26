from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass
from typing import Any

from django.contrib.auth import get_user_model
from django.db import transaction

from lifelog.places.models import Place

from .models import Trip, TripNode, TripTemplate


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
        district=(data.get("district") or None or "").lower() or None,
        limit=max(1, min(int(data.get("limit", 3)), 10)),
        skip_place_ids=data.get("skip_place_ids", []),
    )




def _parse_cost_band(cost_band: str | None) -> tuple[int, int] | None:
    if not cost_band:
        return None
    numbers = [int(value) for value in re.findall(r"\d+", cost_band)]
    if not numbers:
        return None
    low = min(numbers)
    high = max(numbers)
    return low, high


def _budget_level_from_amount(amount: int) -> int:
    if amount <= 15000:
        return 1
    if amount <= 30000:
        return 2
    return 3


def _budget_level_from_label(label: str | None) -> int | None:
    if not label:
        return None
    normalized = label.strip().lower()
    mapping = {
        "cheap": 1,
        "low": 1,
        "budget": 1,
        "moderate": 2,
        "medium": 2,
        "standard": 2,
        "high": 3,
        "premium": 3,
        "expensive": 3,
    }
    return mapping.get(normalized)


def _matches_budget(place: Place, ctx: RecommendationContext) -> bool:
    if ctx.budget_min <= 0 and ctx.budget_max <= 0:
        return True

    parsed = _parse_cost_band(place.cost_band)
    if parsed:
        low, high = parsed
        if ctx.budget_min and high < ctx.budget_min:
            return False
        if ctx.budget_max and low > ctx.budget_max:
            return False
        return True

    level = _budget_level_from_label(place.cost_band)
    if level is None:
        return True

    min_level = 1
    max_level = 3
    if ctx.budget_min > 0:
        min_level = _budget_level_from_amount(ctx.budget_min)
    if ctx.budget_max > 0:
        max_level = _budget_level_from_amount(ctx.budget_max)
    return min_level <= level <= max_level


def _matches_time(place: Place, ctx: RecommendationContext) -> bool:
    if ctx.time_budget_min <= 0:
        return True
    stay = place.stay_min or 0
    if stay == 0:
        return True
    return stay <= ctx.time_budget_min

def _build_context_hash(payload: dict[str, Any]) -> str:
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"))
    return hashlib.sha1(canonical.encode("utf-8")).hexdigest()



def _score_place(place: Place, ctx: RecommendationContext) -> float:
    base = float(place.rating or 0)

    if ctx.mood:
        mood_match = sum(place.mood_scores.get(m, 0) for m in ctx.mood)
        base += mood_match / max(len(ctx.mood), 1)

    if ctx.district and place.district and place.district.lower() == ctx.district:
        base += 0.2

    if ctx.budget_max > 0 or ctx.budget_min > 0:
        parsed = _parse_cost_band(place.cost_band)
        if parsed:
            low, high = parsed
            target = ctx.budget_max or ctx.budget_min
            if target:
                midpoint = (low + high) / 2
                diff_ratio = abs(midpoint - target) / max(target, 1)
                base += max(0.3 - diff_ratio * 0.3, -0.3)
        else:
            base += 0.1  # slight boost when cost info exists and already matched budget filter

    if ctx.time_budget_min > 0:
        stay = place.stay_min or 0
        if stay:
            diff_ratio = abs(stay - ctx.time_budget_min / max(ctx.limit, 1))
            norm = ctx.time_budget_min or 1
            base += max(0.2 - (diff_ratio / norm) * 0.2, -0.2)

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

    budget_filtered = [place for place in candidates if _matches_budget(place, ctx)]
    if budget_filtered:
        candidates = budget_filtered

    time_filtered = [place for place in candidates if _matches_time(place, ctx)]
    if time_filtered:
        candidates = time_filtered

    scored = sorted(candidates, key=lambda place: _score_place(place, ctx), reverse=True)

    selected: list[Place] = []
    remaining_time = ctx.time_budget_min if ctx.time_budget_min > 0 else None

    for place in scored:
        stay = max(place.stay_min or 0, 15)
        if remaining_time is not None and selected and stay > remaining_time:
            continue
        selected.append(place)
        if remaining_time is not None:
            remaining_time = max(0, remaining_time - stay)
        if len(selected) >= ctx.limit:
            break

    if not selected:
        selected = scored[: ctx.limit]

    return selected


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

@transaction.atomic
def create_trip_from_template(template: TripTemplate, owner, title_override: str | None = None) -> Trip:
    title = title_override.strip() if title_override else template.title
    context_payload = {"template_id": str(template.id), "origin": template.origin}
    context_hash = _build_context_hash(context_payload)

    nodes = list(template.nodes.select_related("place"))

    trip = Trip.objects.create(
        owner=owner,
        title=title,
        context_hash=context_hash,
        inputs={"template_id": str(template.id)},
        duration_min=template.duration_min,
        budget_min=template.budget_min,
        budget_max=template.budget_max,
        mode=template.mode,
        summary={
            "source": template.origin,
            "template_slug": template.slug,
            "place_ids": [str(node.place_id) for node in nodes],
        },
    )

    for sequence, node in enumerate(nodes, start=1):
        TripNode.objects.create(
            trip=trip,
            place=node.place,
            sequence=sequence,
            planned_stay_min=node.stay_min,
            transition_mode=trip.mode,
            notes=node.notes or {"template_node_id": str(node.id)},
        )

    return trip

