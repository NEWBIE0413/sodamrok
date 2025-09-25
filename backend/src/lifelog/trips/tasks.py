from __future__ import annotations

from typing import Any

from celery import shared_task

from .services import NoPlacesAvailableError, create_recommendation


@shared_task(name="trips.generate_recommendations")
def generate_trip_recommendations(user_id: str | None, constraints: dict[str, Any] | None = None) -> dict[str, Any]:
    constraints = constraints or {}
    try:
        trip = create_recommendation(user_id, constraints)
        return {"trip_id": str(trip.id), "status": "created"}
    except NoPlacesAvailableError as exc:
        return {"trip_id": None, "status": "error", "error": str(exc)}


@shared_task(name="trips.sync_freshness")
def sync_trip_freshness(trip_id: str) -> dict[str, Any]:
    from .models import Trip

    try:
        trip = Trip.objects.get(id=trip_id)
        trip.freshness_score = 1
        trip.save(update_fields=["freshness_score"])
        return {"trip_id": trip_id, "updated": True}
    except Trip.DoesNotExist:
        return {"trip_id": trip_id, "updated": False, "error": "not_found"}
