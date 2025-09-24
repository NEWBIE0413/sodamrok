from __future__ import annotations

from django.db import models

from lifelog.core.models import TimeStampedModel, UUIDModel


class DailyProductMetric(UUIDModel, TimeStampedModel):
    date = models.DateField()
    metric = models.CharField(max_length=80)
    value = models.DecimalField(max_digits=12, decimal_places=2)
    metadata = models.JSONField(default=dict, blank=True)

    class Meta:
        unique_together = ("date", "metric")
        ordering = ["-date", "metric"]

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.metric}:{self.date}"

