from __future__ import annotations

from typing import Any

from rest_framework import serializers

from lifelog.places.serializers import TagSerializer
from lifelog.places.models import Tag

from .models import (
    Trip,
    TripNode,
    TripTemplate,
    TripTemplateGenerationJob,
    TripTemplateNode,
)


class TripTemplateNodeSerializer(serializers.ModelSerializer):
    place_name = serializers.CharField(source="place.name", read_only=True)

    class Meta:
        model = TripTemplateNode
        fields = (
            "id",
            "place",
            "place_name",
            "sequence",
            "stay_min",
            "notes",
        )
        read_only_fields = ("id", "place_name")


class TripTemplateSerializer(serializers.ModelSerializer):
    nodes = TripTemplateNodeSerializer(many=True, read_only=True)
    tags = TagSerializer(many=True, read_only=True)
    created_by = serializers.UUIDField(source="created_by_id", read_only=True)

    class Meta:
        model = TripTemplate
        fields = (
            "id",
            "slug",
            "title",
            "summary",
            "description",
            "hero_image_url",
            "duration_min",
            "budget_min",
            "budget_max",
            "mode",
            "mood_tags",
            "tags",
            "origin",
            "is_published",
            "created_by",
            "nodes",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("slug", "created_by", "origin")


class TripTemplateWriteSerializer(serializers.ModelSerializer):
    nodes = TripTemplateNodeSerializer(many=True, required=False)
    tag_ids = serializers.ListField(child=serializers.UUIDField(), required=False, allow_empty=True)

    class Meta:
        model = TripTemplate
        fields = (
            "id",
            "title",
            "summary",
            "description",
            "hero_image_url",
            "duration_min",
            "budget_min",
            "budget_max",
            "mode",
            "mood_tags",
            "is_published",
            "tag_ids",
            "nodes",
        )

    def create(self, validated_data):
        tag_ids = validated_data.pop("tag_ids", [])
        nodes_data = validated_data.pop("nodes", [])
        template = TripTemplate.objects.create(**validated_data)
        if tag_ids:
            template.tags.set(Tag.objects.filter(id__in=tag_ids))
        if nodes_data:
            self._sync_nodes(template, nodes_data)
        return template

    def update(self, instance, validated_data):
        tag_ids = validated_data.pop("tag_ids", None)
        nodes_data = validated_data.pop("nodes", None)
        template = super().update(instance, validated_data)
        if tag_ids is not None:
            template.tags.set(Tag.objects.filter(id__in=tag_ids))
        if nodes_data is not None:
            template.nodes.all().delete()
            self._sync_nodes(template, nodes_data)
        return template

    def _sync_nodes(self, template: TripTemplate, nodes_data: list[dict]):
        for index, node_data in enumerate(nodes_data, start=1):
            TripTemplateNode.objects.create(
                template=template,
                place=node_data["place"],
                sequence=node_data.get("sequence", index),
                stay_min=node_data.get("stay_min", 30),
                notes=node_data.get("notes", {}),
            )


class TripTemplateGenerationJobSerializer(serializers.ModelSerializer):
    class Meta:
        model = TripTemplateGenerationJob
        fields = (
            "id",
            "status",
            "prompt",
            "result",
            "error_code",
            "error_detail",
            "model",
            "created_at",
            "updated_at",
            "completed_at",
        )
        read_only_fields = fields


class TripTemplateGenerationJobCreateSerializer(serializers.Serializer):
    BUDGET_LEVEL_CHOICES = (
        ("saver", "Saver"),
        ("standard", "Standard"),
        ("premium", "Premium"),
    )

    brief = serializers.CharField(max_length=600)
    location = serializers.CharField(max_length=120, required=False, allow_blank=True)
    mood_tags = serializers.ListField(
        child=serializers.CharField(max_length=40), required=False, allow_empty=True
    )
    avoid = serializers.ListField(
        child=serializers.CharField(max_length=40), required=False, allow_empty=True
    )
    duration_min = serializers.IntegerField(min_value=30, max_value=720, required=False)
    stops = serializers.IntegerField(min_value=2, max_value=6, required=False)
    budget_level = serializers.ChoiceField(choices=BUDGET_LEVEL_CHOICES, required=False)
    time_of_day = serializers.CharField(max_length=60, required=False, allow_blank=True)
    audience = serializers.CharField(max_length=120, required=False, allow_blank=True)
    additional_notes = serializers.CharField(max_length=500, required=False, allow_blank=True)

    @staticmethod
    def _normalize_strings(values: list[str]) -> list[str]:
        deduped: list[str] = []
        seen: set[str] = set()
        for raw in values:
            item = (raw or "").strip()
            if not item:
                continue
            key = item.lower()
            if key in seen:
                continue
            seen.add(key)
            deduped.append(item[:40])
        return deduped

    def validate_mood_tags(self, value: list[str]) -> list[str]:
        return self._normalize_strings(value)

    def validate_avoid(self, value: list[str]) -> list[str]:
        return self._normalize_strings(value)

    def create(self, validated_data: dict[str, Any]) -> TripTemplateGenerationJob:
        request = self.context.get("request")
        user = getattr(request, "user", None)
        prompt: dict[str, Any] = {}
        for key, value in validated_data.items():
            if value in (None, "", [], {}):
                continue
            if key in {"duration_min", "stops"}:
                prompt[key] = int(value)
            else:
                prompt[key] = value
        job = TripTemplateGenerationJob.objects.create(
            requested_by=user if getattr(user, "is_authenticated", False) else None,
            prompt=prompt,
        )
        return job


class TripFromTemplateRequestSerializer(serializers.Serializer):
    template_id = serializers.UUIDField()
    title = serializers.CharField(required=False, allow_blank=True, max_length=140)


class TripNodeSerializer(serializers.ModelSerializer):
    place_name = serializers.CharField(source="place.name", read_only=True)

    class Meta:
        model = TripNode
        fields = (
            "id",
            "place",
            "place_name",
            "sequence",
            "planned_stay_min",
            "transition_mode",
            "notes",
            "eta",
        )


class TripSerializer(serializers.ModelSerializer):
    nodes = TripNodeSerializer(many=True, read_only=True)

    class Meta:
        model = Trip
        fields = (
            "id",
            "title",
            "owner",
            "context_hash",
            "inputs",
            "duration_min",
            "budget_min",
            "budget_max",
            "mode",
            "freshness_score",
            "summary",
            "nodes",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("owner", "freshness_score")


class TripWriteSerializer(serializers.ModelSerializer):
    nodes = TripNodeSerializer(many=True)

    class Meta:
        model = Trip
        fields = (
            "id",
            "title",
            "context_hash",
            "inputs",
            "duration_min",
            "budget_min",
            "budget_max",
            "mode",
            "summary",
            "nodes",
        )

    def create(self, validated_data):
        nodes_data = validated_data.pop("nodes", [])
        trip = Trip.objects.create(**validated_data)
        self._sync_nodes(trip, nodes_data)
        return trip

    def update(self, instance, validated_data):
        nodes_data = validated_data.pop("nodes", None)
        trip = super().update(instance, validated_data)
        if nodes_data is not None:
            trip.nodes.all().delete()
            self._sync_nodes(trip, nodes_data)
        return trip

    def _sync_nodes(self, trip: Trip, nodes_data: list[dict]):
        for index, node_data in enumerate(nodes_data, start=1):
            TripNode.objects.create(
                trip=trip,
                sequence=node_data.get("sequence", index),
                place=node_data["place"],
                planned_stay_min=node_data.get("planned_stay_min", 30),
                transition_mode=node_data.get("transition_mode", TripNode.TransitionMode.WALK),
                notes=node_data.get("notes", {}),
                eta=node_data.get("eta"),
            )


class TripRecommendationRequestSerializer(serializers.Serializer):
    time_budget_min = serializers.IntegerField(min_value=15, required=False)
    budget_min = serializers.IntegerField(min_value=0, required=False)
    budget_max = serializers.IntegerField(min_value=0, required=False)
    mode = serializers.ChoiceField(choices=Trip.Mode.choices, required=False)
    categories = serializers.ListField(child=serializers.CharField(), required=False, allow_empty=True)
    tags = serializers.ListField(child=serializers.CharField(), required=False, allow_empty=True)
    mood = serializers.ListField(child=serializers.CharField(), required=False, allow_empty=True)
    district = serializers.CharField(required=False, allow_blank=True)
    limit = serializers.IntegerField(min_value=1, max_value=10, required=False, default=3)
    skip_place_ids = serializers.ListField(child=serializers.UUIDField(), required=False, allow_empty=True)
