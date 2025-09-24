from __future__ import annotations

from rest_framework import serializers

from lifelog.places.serializers import TagSerializer
from lifelog.places.models import Tag

from .models import Post


class PostSerializer(serializers.ModelSerializer):
    tags = TagSerializer(many=True, read_only=True)
    author_id = serializers.UUIDField(source="author.id", read_only=True)

    class Meta:
        model = Post
        fields = (
            "id",
            "author_id",
            "place",
            "title",
            "body",
            "post_type",
            "visibility",
            "status",
            "published_at",
            "media_urls",
            "tags",
            "geofence",
            "expires_at",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("status", "published_at")


class PostWriteSerializer(serializers.ModelSerializer):
    tag_ids = serializers.ListField(child=serializers.UUIDField(), write_only=True, required=False)

    class Meta:
        model = Post
        fields = (
            "id",
            "place",
            "title",
            "body",
            "post_type",
            "visibility",
            "media_urls",
            "tag_ids",
            "geofence",
            "expires_at",
        )

    def create(self, validated_data):
        tag_ids = validated_data.pop("tag_ids", [])
        post = Post.objects.create(**validated_data)
        if tag_ids:
            post.tags.set(Tag.objects.filter(id__in=tag_ids))
        return post

    def update(self, instance, validated_data):
        tag_ids = validated_data.pop("tag_ids", None)
        post = super().update(instance, validated_data)
        if tag_ids is not None:
            post.tags.set(Tag.objects.filter(id__in=tag_ids))
        return post

