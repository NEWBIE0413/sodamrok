from __future__ import annotations

from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from lifelog.places.models import Place
from lifelog.posts.models import Post, PostComment, PostLike


class PostAPITests(APITestCase):
    def setUp(self):
        super().setUp()
        User = get_user_model()
        self.user1 = User.objects.create_user(email="user1@example.com", password="User1Pass!23", nickname="소담이")
        self.user1.display_name = "소담 기록가"
        self.user1.save(update_fields=["display_name"])
        self.user2 = User.objects.create_user(email="user2@example.com", password="User2Pass!23")
        self.place = Place.objects.create(name="Cafe Alpha", category="cafe")

    def authenticate(self, email: str, password: str):
        response = self.client.post(
            "/api/auth/token/",
            {"email": email, "password": password},
            format="json",
        )
        token = response.data["access"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")

    def test_user_can_create_and_list_own_posts(self):
        self.authenticate("user1@example.com", "User1Pass!23")
        payload = {
            "place": str(self.place.id),
            "title": "후기",
            "body": "아늑한 공간",
            "post_type": "review",
            "visibility": "private",
        }
        create_response = self.client.post("/api/v1/posts/", payload, format="json")
        self.assertEqual(create_response.status_code, status.HTTP_201_CREATED)

        list_response = self.client.get("/api/v1/posts/")
        self.assertEqual(list_response.status_code, status.HTTP_200_OK)
        results = list_response.data["results"]
        self.assertEqual(list_response.data["count"], 1)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["title"], "후기")

    def test_user_cannot_modify_other_users_post(self):
        self.authenticate("user1@example.com", "User1Pass!23")
        post = Post.objects.create(
            author=self.user1,
            place=self.place,
            title="테스트",
            body="내용",
        )
        self.authenticate("user2@example.com", "User2Pass!23")
        update = {"title": "변경"}
        response = self.client.patch(f"/api/v1/posts/{post.id}/", update, format="json")
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

        list_response = self.client.get("/api/v1/posts/")
        self.assertEqual(list_response.status_code, status.HTTP_200_OK)
        results = list_response.data["results"]
        self.assertEqual(list_response.data["count"], 0)
        self.assertEqual(len(results), 0)

    def test_unauthenticated_user_cannot_create_post(self):
        payload = {
            "place": str(self.place.id),
            "title": "비로그인",
            "body": "불가",
            "post_type": "review",
            "visibility": "private",
        }
        response = self.client.post("/api/v1/posts/", payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_public_feed_includes_author_and_counts(self):
        post = Post.objects.create(
            author=self.user1,
            place=self.place,
            title="공개 후기",
            body="분위기 좋은 카페",
            post_type=Post.PostType.REVIEW,
            visibility=Post.Visibility.PUBLIC,
            status=Post.Status.PUBLISHED,
            published_at=timezone.now(),
            media_urls=["https://example.com/photo.jpg"],
        )
        PostLike.objects.create(post=post, user=self.user2)
        PostComment.objects.create(post=post, author=self.user2, content="좋아요")

        response = self.client.get("/api/v1/posts/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["count"], 1)
        result = response.data["results"][0]
        self.assertEqual(result["like_count"], 1)
        self.assertEqual(result["comment_count"], 1)
        self.assertEqual(result["author"]["id"], str(self.user1.id))
        self.assertEqual(result["author"]["nickname"], "소담이")
        self.assertEqual(result["author_name"], "소담이")
        self.assertIn("media_urls", result)

    def test_like_endpoint_returns_updated_counts(self):
        post = Post.objects.create(
            author=self.user1,
            place=self.place,
            title="테스트",
            body="내용",
            post_type=Post.PostType.REVIEW,
            visibility=Post.Visibility.PUBLIC,
            status=Post.Status.PUBLISHED,
            published_at=timezone.now(),
        )
        self.authenticate("user2@example.com", "User2Pass!23")
        like_response = self.client.post(f"/api/v1/posts/{post.id}/like/")
        self.assertEqual(like_response.status_code, status.HTTP_200_OK)
        self.assertEqual(like_response.data["like_count"], 1)
        self.assertEqual(like_response.data["comment_count"], 0)
        self.assertEqual(like_response.data["post_id"], str(post.id))

        unlike_response = self.client.delete(f"/api/v1/posts/{post.id}/like/")
        self.assertEqual(unlike_response.status_code, status.HTTP_200_OK)
        self.assertEqual(unlike_response.data["like_count"], 0)

    def test_comment_flow_requires_auth_and_returns_payload(self):
        post = Post.objects.create(
            author=self.user1,
            place=self.place,
            title="테스트",
            body="내용",
            post_type=Post.PostType.REVIEW,
            visibility=Post.Visibility.PUBLIC,
            status=Post.Status.PUBLISHED,
            published_at=timezone.now(),
        )

        unauth_response = self.client.post(
            f"/api/v1/posts/{post.id}/comments/",
            {"content": "첫 댓글"},
            format="json",
        )
        self.assertEqual(unauth_response.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertEqual(unauth_response.data["detail"], "로그인이 필요합니다.")

        self.authenticate("user2@example.com", "User2Pass!23")
        create_response = self.client.post(
            f"/api/v1/posts/{post.id}/comments/",
            {"content": "첫 댓글"},
            format="json",
        )
        self.assertEqual(create_response.status_code, status.HTTP_201_CREATED)
        self.assertIn("comment", create_response.data)
        self.assertEqual(create_response.data["comment"]["content"], "첫 댓글")
        self.assertEqual(create_response.data["comment_count"], 1)

