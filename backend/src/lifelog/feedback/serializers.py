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

    def validate(self, attrs):
        request = self.context.get("request")
        user = getattr(request, "user", None)
        trip = attrs.get("trip")
        if user and not getattr(user, "is_staff", False):
            if trip and trip.owner_id != user.id:
                raise serializers.ValidationError({"trip": "trip_mismatch"})
        trip_node = attrs.get("trip_node")
        if trip_node and trip_node.trip_id != trip.id:
            raise serializers.ValidationError({"trip_node": "trip_node_mismatch"})
        return attrs

