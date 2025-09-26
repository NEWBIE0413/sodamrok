from __future__ import annotations

import uuid

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand
from django.db import transaction
from django.utils import timezone

from lifelog.posts.models import Post, PostComment, PostLike


class Command(BaseCommand):
    help = "Create sample data for the home feed so the Flutter app can render immediately."

    def handle(self, *args, **options):
        User = get_user_model()

        with transaction.atomic():
            author = self._ensure_user(
                User,
                email="feed-author@example.com",
                password="FeedDemo123!",
                display_name="소담 기록가",
                nickname="소담이",
            )
            friend = self._ensure_user(
                User,
                email="feed-friend@example.com",
                password="FeedDemo123!",
                display_name="도보 메이트",
                nickname="메이트",
            )

            post = self._ensure_post(author)
            self._ensure_feedback(post, friend)

        self.stdout.write(self.style.SUCCESS("Home feed sample data is ready."))

    def _ensure_user(self, User, *, email: str, password: str, display_name: str, nickname: str):
        user = User.objects.filter(email=email).first()
        updated_fields: list[str] = []

        if not user:
            user = User.objects.create_user(
                email=email,
                password=password,
                display_name=display_name,
                nickname=nickname,
                privacy_level=User.PrivacyLevel.PUBLIC,
            )
            return user

        if user.display_name != display_name:
            user.display_name = display_name
            updated_fields.append("display_name")
        if user.nickname != nickname:
            user.nickname = nickname
            updated_fields.append("nickname")
        if user.privacy_level != User.PrivacyLevel.PUBLIC:
            user.privacy_level = User.PrivacyLevel.PUBLIC
            updated_fields.append("privacy_level")

        if updated_fields:
            user.save(update_fields=updated_fields)
        if not user.has_usable_password():
            user.set_password(password)
            user.save(update_fields=["password"])

        return user

    def _ensure_post(self, author: Post.author.field.related_model) -> Post:
        post_id = uuid.UUID("3e6cdb0b-2ef9-4833-9f46-a77d83ef8f7b")
        defaults = {
            "author": author,
            "title": "소담동 가을 감성 산책",
            "body": "북카페 → 골목 전시 → 야외 테라스로 이어지는 3코스 산책 루트를 기록했어요.",
            "post_type": Post.PostType.REVIEW,
            "visibility": Post.Visibility.PUBLIC,
            "status": Post.Status.PUBLISHED,
            "published_at": timezone.now(),
            "media_urls": [
                "https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?auto=compress&fit=crop&w=960&q=80"
            ],
            "geofence": {},
        }
        post, _ = Post.objects.update_or_create(id=post_id, defaults=defaults)
        return post

    def _ensure_feedback(self, post: Post, friend):
        PostLike.objects.update_or_create(post=post, user=friend, defaults={})

        comment_id = uuid.UUID("74c7f6d8-053d-4f9f-8c7f-5f6db1d36a0e")
        PostComment.objects.update_or_create(
            id=comment_id,
            defaults={
                "post": post,
                "author": friend,
                "content": "진짜 힐링되는 코스네요! 다음 주말에 따라가 볼게요.",
            },
        )

