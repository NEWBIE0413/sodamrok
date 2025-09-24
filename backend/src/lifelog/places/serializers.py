from __future__ import annotations

from rest_framework import serializers

from .models import Place, Tag


class TagSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tag
        fields = ("id", "name", "type", "metadata")


class PlaceSerializer(serializers.ModelSerializer):
    tags = TagSerializer(many=True, read_only=True)

    class Meta:
        model = Place
        fields = (
            "id",
            "name",
            "slug",
            "external_ref",
            "category",
            "description",
            "address",
            "district",
            "location",
            "cost_band",
            "stay_min",
            "hours",
            "mood_scores",
            "congestion_score",
            "rating",
            "tags",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("slug", "rating")


class PlaceWriteSerializer(serializers.ModelSerializer):
    tag_ids = serializers.ListField(child=serializers.UUIDField(), write_only=True, required=False)

    class Meta:
        model = Place
        fields = (
            "id",
            "name",
            "slug",
            "external_ref",
            "category",
            "description",
            "address",
            "district",
            "location",
            "cost_band",
            "stay_min",
            "hours",
            "mood_scores",
            "congestion_score",
            "rating",
            "tag_ids",
        )
        read_only_fields = ("slug", "rating")

    def create(self, validated_data):
        tag_ids = validated_data.pop("tag_ids", [])
        place = super().create(validated_data)
        if tag_ids:
            place.tags.set(Tag.objects.filter(id__in=tag_ids))
        return place

    def update(self, instance, validated_data):
        tag_ids = validated_data.pop("tag_ids", None)
        place = super().update(instance, validated_data)
        if tag_ids is not None:
            place.tags.set(Tag.objects.filter(id__in=tag_ids))
        return place

