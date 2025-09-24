from __future__ import annotations

from django.db import models

from lifelog.core.models import TimeStampedModel, UUIDModel


class Post(UUIDModel, TimeStampedModel):
    class PostType(models.TextChoices):
        REVIEW = "review", "후기"
        DOODLE = "doodle", "낙서"

    class Visibility(models.TextChoices):
        PRIVATE = "private", "비공개"
        FRIENDS = "friends", "친구공개"
        PUBLIC = "public", "전체공개"

    class Status(models.TextChoices):
        DRAFT = "draft", "작성중"
        PUBLISHED = "published", "게시됨"
        FLAGGED = "flagged", "검토 필요"
        ARCHIVED = "archived", "보관"

    author = models.ForeignKey("users.User", on_delete=models.CASCADE, related_name="posts")
    place = models.ForeignKey("places.Place", on_delete=models.SET_NULL, null=True, blank=True, related_name="posts")
    title = models.CharField(max_length=140, blank=True)
    body = models.TextField(blank=True)
    post_type = models.CharField(max_length=20, choices=PostType.choices, default=PostType.REVIEW)
    visibility = models.CharField(max_length=20, choices=Visibility.choices, default=Visibility.PRIVATE)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PUBLISHED)
    published_at = models.DateTimeField(null=True, blank=True)
    media_urls = models.JSONField(default=list, blank=True)
    tags = models.ManyToManyField("places.Tag", through="PostTag", related_name="posts")
    geofence = models.JSONField(default=dict, blank=True)
    expires_at = models.DateTimeField(null=True, blank=True, help_text="낙서 24시간 만료용")

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["post_type", "status"]),
            models.Index(fields=["visibility"]),
        ]

    def __str__(self) -> str:  # pragma: no cover
        return self.title or self.post_type


class PostTag(models.Model):
    post = models.ForeignKey(Post, on_delete=models.CASCADE)
    tag = models.ForeignKey("places.Tag", on_delete=models.CASCADE)

    class Meta:
        unique_together = ("post", "tag")

