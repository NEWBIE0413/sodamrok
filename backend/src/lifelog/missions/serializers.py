from __future__ import annotations

from rest_framework import serializers

from .models import Mission, MissionAssignment


class MissionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Mission
        fields = (
            "id",
            "title",
            "description",
            "steps",
            "badge_type",
            "is_active",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("is_active",)


class MissionAssignmentSerializer(serializers.ModelSerializer):
    mission = MissionSerializer(read_only=True)
    mission_id = serializers.PrimaryKeyRelatedField(
        source="mission",
        queryset=Mission.objects.all(),
        write_only=True,
        required=False,
    )

    class Meta:
        model = MissionAssignment
        fields = (
            "id",
            "mission",
            "mission_id",
            "user",
            "assigned_at",
            "due_at",
            "status",
            "result_metadata",
            "completed_at",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("user", "assigned_at", "completed_at", "created_at", "updated_at")

