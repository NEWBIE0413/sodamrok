from __future__ import annotations

import logging
from typing import Any

from celery import shared_task
from django.utils import timezone

from lifelog.core.clients.openrouter import (
    OpenRouterClient,
    OpenRouterConfigurationError,
    OpenRouterError,
)

from .ai import build_messages, normalize_template_payload
from .models import TripTemplateGenerationJob
from .services import NoPlacesAvailableError, create_recommendation

logger = logging.getLogger(__name__)


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


@shared_task(name="trips.request_ai_template")
def request_ai_template(job_id: str) -> dict[str, Any]:
    try:
        job = TripTemplateGenerationJob.objects.get(id=job_id)
    except TripTemplateGenerationJob.DoesNotExist:
        logger.warning("AI template job not found: %s", job_id)
        return {"status": "error", "error": "job_not_found"}

    if job.status == TripTemplateGenerationJob.Status.COMPLETED:
        return {"status": "completed", "job_id": str(job.id)}
    if job.status == TripTemplateGenerationJob.Status.RUNNING:
        return {"status": "running", "job_id": str(job.id)}

    try:
        client = OpenRouterClient()
    except OpenRouterConfigurationError as exc:
        job.mark_failed("openrouter_not_configured", str(exc))
        return {"status": "error", "error": "openrouter_not_configured"}

    job.mark_running(model_name=client.model)

    try:
        messages = build_messages(job.prompt or {})
        response_payload = client.complete_json(messages)
        normalized = normalize_template_payload(response_payload)
    except OpenRouterConfigurationError as exc:
        job.mark_failed("openrouter_not_configured", str(exc))
        return {"status": "error", "error": "openrouter_not_configured"}
    except OpenRouterError as exc:
        job.mark_failed("openrouter_error", str(exc))
        return {"status": "error", "error": str(exc)}
    except Exception as exc:  # pragma: no cover - defensive guard
        logger.exception("Unexpected error while processing AI template job %s", job.id)
        job.mark_failed("processing_error", str(exc))
        return {"status": "error", "error": "processing_error"}

    job.result = normalized
    job.status = TripTemplateGenerationJob.Status.COMPLETED
    job.completed_at = timezone.now()
    job.save(update_fields=["status", "result", "completed_at", "updated_at"])

    logger.info("AI template job %s completed", job.id)
    return {"status": "completed", "job_id": str(job.id), "template": normalized}
