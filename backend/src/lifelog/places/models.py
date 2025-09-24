from __future__ import annotations

from django.db import models
from django.utils.text import slugify

from lifelog.core.models import SoftDeleteModel, TimeStampedModel, UUIDModel


class Tag(UUIDModel, TimeStampedModel):
    class Type(models.TextChoices):
        CATEGORY = "category", "카테고리"
        MOOD = "mood", "분위기"
        TIME = "time", "시간대"
        CONGESTION = "congestion", "혼잡도"
        BUDGET = "budget", "예산"
        CUSTOM = "custom", "사용자 정의"

    name = models.CharField(max_length=80)
    type = models.CharField(max_length=20, choices=Type.choices, default=Type.CATEGORY)
    metadata = models.JSONField(default=dict, blank=True)

    class Meta:
        unique_together = ("name", "type")
        ordering = ["name"]

    def __str__(self) -> str:  # pragma: no cover - human readable helper
        return f"{self.name} ({self.type})"


class Place(UUIDModel, TimeStampedModel, SoftDeleteModel):
    name = models.CharField(max_length=150)
    slug = models.SlugField(max_length=160, unique=True, blank=True)
    external_ref = models.CharField(max_length=120, blank=True)
    category = models.CharField(max_length=60)
    description = models.TextField(blank=True)
    address = models.CharField(max_length=255, blank=True)
    district = models.CharField(max_length=120, blank=True)
    location = models.JSONField(default=dict, blank=True, help_text="GeoJSON Point representation")
    cost_band = models.CharField(max_length=30, blank=True)
    stay_min = models.PositiveIntegerField(default=60)
    hours = models.JSONField(default=dict, blank=True)
    mood_scores = models.JSONField(default=dict, blank=True)
    congestion_score = models.DecimalField(max_digits=4, decimal_places=2, default=0)
    rating = models.DecimalField(max_digits=3, decimal_places=2, default=0)

    tags = models.ManyToManyField(Tag, through="PlaceTag", related_name="places")

    class Meta:
        ordering = ["name"]
        indexes = [
            models.Index(fields=["category"]),
            models.Index(fields=["district"]),
        ]

    def save(self, *args, **kwargs):  # pragma: no cover - simple helper
        if not self.slug:
            self.slug = slugify(self.name)
        super().save(*args, **kwargs)

    def __str__(self) -> str:  # pragma: no cover
        return self.name


class PlaceTag(models.Model):
    place = models.ForeignKey(Place, on_delete=models.CASCADE)
    tag = models.ForeignKey(Tag, on_delete=models.CASCADE)
    weight = models.DecimalField(max_digits=4, decimal_places=2, default=1)

    class Meta:
        unique_together = ("place", "tag")

