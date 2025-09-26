from __future__ import annotations

from django.db import models
from django.conf import settings
from django.utils import timezone
from django.utils.text import slugify
import uuid

from lifelog.core.models import TimeStampedModel, UUIDModel


class Trip(UUIDModel, TimeStampedModel):
    class Mode(models.TextChoices):
        WALK = "walk", "도보"
        TRANSIT = "transit", "대중교통"
        BIKE = "bike", "자전거"
        DRIVE = "drive", "자가용"

    owner = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="trips", null=True, blank=True)
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

class TripTemplate(UUIDModel, TimeStampedModel):
    class Origin(models.TextChoices):
        EDITOR = "editor", "에디터"
        AI = "ai", "AI"

    title = models.CharField(max_length=140)
    slug = models.SlugField(max_length=160, unique=True, blank=True)
    summary = models.CharField(max_length=200, blank=True)
    description = models.TextField(blank=True)
    hero_image_url = models.URLField(blank=True)
    duration_min = models.PositiveIntegerField(default=90)
    budget_min = models.PositiveIntegerField(default=0)
    budget_max = models.PositiveIntegerField(default=0)
    mode = models.CharField(max_length=16, choices=Trip.Mode.choices, default=Trip.Mode.WALK)
    mood_tags = models.JSONField(default=list, blank=True)
    tags = models.ManyToManyField("places.Tag", related_name="trip_templates", blank=True)
    origin = models.CharField(max_length=20, choices=Origin.choices, default=Origin.EDITOR)
    is_published = models.BooleanField(default=False)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="created_trip_templates")

    class Meta:
        ordering = ["-created_at"]
        indexes = [models.Index(fields=["is_published", "created_at"])]

    def save(self, *args, **kwargs):  # pragma: no cover - helper
        if not self.slug:
            slug_candidate = slugify(self.title)
            if not slug_candidate:
                slug_candidate = uuid.uuid4().hex
            self.slug = slug_candidate
        super().save(*args, **kwargs)

    def __str__(self) -> str:  # pragma: no cover
        return self.title


class TripTemplateNode(UUIDModel, TimeStampedModel):
    template = models.ForeignKey(TripTemplate, on_delete=models.CASCADE, related_name="nodes")
    place = models.ForeignKey("places.Place", on_delete=models.CASCADE, related_name="template_nodes")
    sequence = models.PositiveIntegerField()
    stay_min = models.PositiveIntegerField(default=30)
    notes = models.JSONField(default=dict, blank=True)

    class Meta:
        ordering = ["sequence"]
        unique_together = ("template", "sequence")

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.template_id}:{self.sequence}"



class TripTemplateGenerationJob(UUIDModel, TimeStampedModel):
    class Status(models.TextChoices):
        QUEUED = "queued", "Queued"
        RUNNING = "running", "Running"
        COMPLETED = "completed", "Completed"
        FAILED = "failed", "Failed"

    requested_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="ai_template_jobs")
    prompt = models.JSONField(default=dict, blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.QUEUED)
    result = models.JSONField(default=dict, blank=True)
    error_code = models.CharField(max_length=60, blank=True)
    error_detail = models.TextField(blank=True)
    model = models.CharField(max_length=80, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["requested_by", "created_at"]),
            models.Index(fields=["status", "created_at"]),
        ]

    def __str__(self) -> str:  # pragma: no cover
        return f"AI Trip Template Job {self.id}"

    def mark_running(self, model_name: str | None = None):
        fields = ["status", "updated_at", "error_code", "error_detail", "completed_at"]
        self.status = self.Status.RUNNING
        self.error_code = ""
        self.error_detail = ""
        self.completed_at = None
        if model_name:
            self.model = model_name
            fields.append("model")
        self.save(update_fields=fields)

    def mark_failed(self, code: str, detail: str = ""):
        self.status = self.Status.FAILED
        self.error_code = code
        self.error_detail = (detail or "")[:2000]
        self.completed_at = timezone.now()
        self.save(update_fields=["status", "error_code", "error_detail", "completed_at", "updated_at"])



