from __future__ import annotations

from rest_framework import serializers

from .models import PartyMember, PartyPosition, PartySession


class PartyMemberSerializer(serializers.ModelSerializer):
    user_id = serializers.UUIDField(source="user.id", read_only=True)

    class Meta:
        model = PartyMember
        fields = ("id", "user_id", "role", "is_active", "created_at")


class PartySessionSerializer(serializers.ModelSerializer):
    members = PartyMemberSerializer(many=True, read_only=True)

    class Meta:
        model = PartySession
        fields = (
            "id",
            "trip",
            "host_user",
            "status",
            "started_at",
            "ended_at",
            "sharable_token",
            "precision",
            "options",
            "members",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("host_user", "status", "started_at", "ended_at")


class PartySessionCreateSerializer(serializers.ModelSerializer):
    member_ids = serializers.ListField(child=serializers.UUIDField(), required=False)

    class Meta:
        model = PartySession
        fields = (
            "trip",
            "precision",
            "options",
            "member_ids",
        )

    def create(self, validated_data):
        member_ids = validated_data.pop("member_ids", [])
        session = PartySession.objects.create(**validated_data)
        PartyMember.objects.create(session=session, user=session.host_user, role=PartyMember.Role.GUIDE)
        unique_ids = []
        seen = {session.host_user_id}
        for raw_id in member_ids:
            if raw_id in seen:
                continue
            seen.add(raw_id)
            unique_ids.append(raw_id)
        if unique_ids:
            PartyMember.objects.bulk_create(
                [
                    PartyMember(session=session, user_id=user_id, role=PartyMember.Role.MEMBER)
                    for user_id in unique_ids
                ]
            )
        return session


class PartyPositionSerializer(serializers.ModelSerializer):
    class Meta:
        model = PartyPosition
        fields = (
            "id",
            "session",
            "user",
            "loc",
            "accuracy_m",
            "recorded_at",
        )
        read_only_fields = ("user", "recorded_at")


