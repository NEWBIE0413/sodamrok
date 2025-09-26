from __future__ import annotations

from rest_framework import serializers

from .models import FavoritePlace, Place, Tag


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



class FavoritePlaceSerializer(serializers.ModelSerializer):
    place = PlaceSerializer(read_only=True)
    place_id = serializers.UUIDField(write_only=True)

    class Meta:
        model = FavoritePlace
        fields = ("id", "place", "place_id", "note", "created_at")
        read_only_fields = ("id", "place", "created_at")

    def validate_place_id(self, value):
        if not Place.objects.filter(id=value, is_active=True).exists():
            raise serializers.ValidationError("Place does not exist or is inactive.")
        return value

    def create(self, validated_data):
        place_id = validated_data.pop("place_id")
        request = self.context.get("request")
        user = getattr(request, "user", None)
        place = Place.objects.get(id=place_id)
        favorite, created = FavoritePlace.objects.update_or_create(
            user=user, place=place, defaults={"note": validated_data.get("note", "")}
        )
        if not created and "note" in validated_data:
            favorite.note = validated_data["note"]
            favorite.save(update_fields=["note"])
        return favorite

    def update(self, instance, validated_data):
        if "place_id" in validated_data:
            raise serializers.ValidationError({"place_id": "Cannot change place for a favorite."})
        note = validated_data.get("note", instance.note)
        instance.note = note
        instance.save(update_fields=["note"])
        return instance

