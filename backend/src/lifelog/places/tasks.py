from __future__ import annotations

from typing import Any

from celery import shared_task

from .models import Place


@shared_task(name="places.refresh_metadata")
def refresh_place_metadata(place_id: str, metadata: dict[str, Any] | None = None) -> dict[str, Any]:
    metadata = metadata or {}
    try:
        place = Place.objects.get(id=place_id)
        updated = metadata.get("mood_scores") or {}
        if updated:
            place.mood_scores.update(updated)
        place.save(update_fields=["mood_scores", "updated_at"])
        return {"place_id": place_id, "updated": True, "applied_keys": list(updated.keys())}
    except Place.DoesNotExist:
        return {"place_id": place_id, "updated": False, "error": "not_found"}

