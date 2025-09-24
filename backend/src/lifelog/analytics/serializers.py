from __future__ import annotations

from rest_framework import serializers

from .models import DailyProductMetric


class DailyProductMetricSerializer(serializers.ModelSerializer):
    class Meta:
        model = DailyProductMetric
        fields = ("id", "date", "metric", "value", "metadata", "created_at")

