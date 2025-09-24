from __future__ import annotations

from django.db import models

from lifelog.core.models import TimeStampedModel, UUIDModel


class Trip(UUIDModel, TimeStampedModel):
    class Mode(models.TextChoices):
        WALK = "walk", "도보"
        TRANSIT = "transit", "대중교통"
        BIKE = "bike", "자전거"
        DRIVE = "drive", "자가용"

    owner = models.ForeignKey("users.User", on_delete=models.CASCADE, related_name="trips", null=True, blank=True)
    title = models.CharField(max_length=140, blank=True)
    context_hash = models.CharField(max_length=64, db_index=True)
    inputs = models.JSONField(default=dict, blank=True, help_text="요청시 제약 조건 기록")
    duration_min = models.PositiveIntegerField(default=90)
    budget_min = models.PositiveIntegerField(default=0)
    budget_max = models.PositiveIntegerField(default=0)
    mode = models.CharField(max_length=16, choices=Mode.choices, default=Mode.WALK)
    freshness_score = models.DecimalField(max_digits=4, decimal_places=2, default=1)
    summary = models.JSONField(default=dict, blank=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["context_hash"]),
        ]

    def __str__(self) -> str:  # pragma: no cover
        return self.title or f"Trip {self.id}"


class TripNode(UUIDModel, TimeStampedModel):
    class TransitionMode(models.TextChoices):
        WALK = "walk", "도보"
        TRANSIT = "transit", "대중교통"
        BIKE = "bike", "자전거"
        DRIVE = "drive", "자가용"

    trip = models.ForeignKey(Trip, on_delete=models.CASCADE, related_name="nodes")
    place = models.ForeignKey("places.Place", on_delete=models.CASCADE, related_name="trip_nodes")
    sequence = models.PositiveIntegerField()
    planned_stay_min = models.PositiveIntegerField(default=30)
    transition_mode = models.CharField(max_length=16, choices=TransitionMode.choices, default=TransitionMode.WALK)
    notes = models.JSONField(default=dict, blank=True)
    eta = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["sequence"]
        unique_together = ("trip", "sequence")

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.trip_id}:{self.sequence}"

