from __future__ import annotations

from rest_framework import serializers

from .models import Mission, MissionAssignment
from . import services


class MissionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Mission
        fields = (
            "id",
            "title",
            "description",
            "steps",
            "badge_type",
            "frequency",
            "reward_type",
            "reward_code",
            "reward_amount",
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
    reward = serializers.SerializerMethodField()

    class Meta:
        model = MissionAssignment
        fields = (
            "id",
            "mission",
            "mission_id",
            "user",
            "assigned_at",
            "date_for",
            "due_at",
            "status",
            "result_metadata",
            "completed_at",
            "reward_granted",
            "reward",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "user",
            "assigned_at",
            "completed_at",
            "reward_granted",
            "reward",
            "created_at",
            "updated_at",
        )

    def get_reward(self, obj: MissionAssignment) -> dict[str, object]:
        mission = obj.mission
        return {
            "type": mission.reward_type,
            "code": mission.reward_code,
            "amount": mission.reward_amount,
        }

    def create(self, validated_data):
        assignment = super().create(validated_data)
        return assignment

    def update(self, instance, validated_data):
        metadata = validated_data.pop("result_metadata", None)
        status = validated_data.pop("status", None)

        for field, value in validated_data.items():
            setattr(instance, field, value)
        if validated_data:
            instance.save()

        if status == MissionAssignment.Status.COMPLETED:
            services.complete_assignment(instance, metadata=metadata)
            instance.refresh_from_db()
        else:
            if status is not None:
                instance.status = status
                instance.save(update_fields=["status"])
            if metadata is not None:
                instance.result_metadata = metadata
                instance.save(update_fields=["result_metadata"])
        return instance
