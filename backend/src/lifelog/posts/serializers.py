from __future__ import annotations

from rest_framework import serializers

from lifelog.places.serializers import TagSerializer
from lifelog.places.models import Tag

from .models import Post, PostComment


class PostSerializer(serializers.ModelSerializer):
    tags = TagSerializer(many=True, read_only=True)
    author = serializers.SerializerMethodField()
    author_id = serializers.UUIDField(source="author.id", read_only=True)
    author_name = serializers.SerializerMethodField()
    like_count = serializers.IntegerField(read_only=True)
    comment_count = serializers.IntegerField(read_only=True)
    is_liked = serializers.SerializerMethodField()

    class Meta:
        model = Post
        fields = (
            "id",
            "author",
            "author_id",
            "author_name",
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
            "like_count",
            "comment_count",
            "is_liked",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "status",
            "published_at",
            "like_count",
            "comment_count",
            "is_liked",
            "author",
            "author_id",
            "author_name",
        )

    def get_author(self, obj):
        author = obj.author
        avatar = (author.avatar or "").strip()
        return {
            "id": str(author.id),
            "display_name": author.display_name,
            "nickname": author.nickname,
            "avatar": avatar or None,
        }

    def get_author_name(self, obj) -> str:
        author = obj.author
        if author.nickname:
            return author.nickname
        if author.display_name:
            return author.display_name
        local_part = author.email.split("@", 1)[0] if author.email else ""
        return local_part or "소담 기록가"

    def get_is_liked(self, obj):
        request = self.context.get("request")
        user = getattr(request, "user", None)
        if not getattr(user, "is_authenticated", False):
            return False
        cache = getattr(obj, "_prefetched_objects_cache", {})
        if "likes" in cache:
            return any(like.user_id == user.id for like in cache["likes"])
        return obj.likes.filter(user=user).exists()


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

class PostCommentSerializer(serializers.ModelSerializer):
    author = serializers.SerializerMethodField()

    class Meta:
        model = PostComment
        fields = ("id", "post", "author", "content", "created_at")
        read_only_fields = ("id", "post", "author", "created_at")

    def get_author(self, obj):
        author = obj.author
        return {
            "id": str(author.id),
            "display_name": author.display_name,
            "nickname": author.nickname,
        }


class PostCommentCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = PostComment
        fields = ("content",)

    def validate_content(self, value: str) -> str:
        cleaned = value.strip() if value else ""
        if not cleaned:
            raise serializers.ValidationError("댓글 내용을 입력해 주세요.")
        if len(cleaned) > 1000:
            raise serializers.ValidationError("댓글은 1,000자 이내로 작성해 주세요.")
        return cleaned
