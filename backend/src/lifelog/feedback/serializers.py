from __future__ import annotations

from rest_framework import serializers

from .models import Feedback


class FeedbackSerializer(serializers.ModelSerializer):
    class Meta:
        model = Feedback
        fields = (
            "id",
            "trip",
            "trip_node",
            "user",
            "rating",
            "stay_actual_min",
            "comments",
            "metadata",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("user", "created_at", "updated_at")


class FeedbackCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Feedback
        fields = (
            "trip",
            "trip_node",
            "rating",
            "stay_actual_min",
            "comments",
            "metadata",
        )

