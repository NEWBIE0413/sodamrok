from __future__ import annotations

from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

from lifelog.places.models import Place
from lifelog.posts.models import Post


class PostAPITests(APITestCase):
    def setUp(self):
        super().setUp()
        User = get_user_model()
        self.user1 = User.objects.create_user(email="user1@example.com", password="User1Pass!23")
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
        post = Post.objects.create(author=self.user1, place=self.place, title="테스트", body="내용")
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

