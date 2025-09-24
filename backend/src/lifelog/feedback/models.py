from __future__ import annotations

from django.db import models

from lifelog.core.models import TimeStampedModel, UUIDModel


class Feedback(UUIDModel, TimeStampedModel):
    class Rating(models.IntegerChoices):
        BAD = 1, "별로"
        NEUTRAL = 2, "보통"
        GOOD = 3, "좋았어요"

    trip = models.ForeignKey("trips.Trip", on_delete=models.CASCADE, related_name="feedback")
    trip_node = models.ForeignKey("trips.TripNode", on_delete=models.SET_NULL, null=True, blank=True, related_name="feedback")
    user = models.ForeignKey("users.User", on_delete=models.CASCADE, related_name="feedback")
    rating = models.IntegerField(choices=Rating.choices, default=Rating.GOOD)
    stay_actual_min = models.PositiveIntegerField(default=0)
    comments = models.TextField(blank=True)
    metadata = models.JSONField(default=dict, blank=True)

    class Meta:
        ordering = ["-created_at"]
        unique_together = ("trip", "user", "trip_node")

    def __str__(self) -> str:  # pragma: no cover
        return f"Feedback {self.trip_id}:{self.rating}"

