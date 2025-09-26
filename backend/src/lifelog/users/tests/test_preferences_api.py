from __future__ import annotations

from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

from lifelog.places.models import Tag


class UserPreferredTagAPITests(APITestCase):
    def setUp(self):
        super().setUp()
        User = get_user_model()
        self.user = User.objects.create_user(email="pref@example.com", password="PrefPass123!")
        self.tag = Tag.objects.create(name="sunny", type=Tag.Type.MOOD)

    def authenticate(self):
        response = self.client.post(
            "/api/auth/token/",
            {"email": "pref@example.com", "password": "PrefPass123!"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {response.data['access']}")

    def test_create_and_list_preferred_tag(self):
        self.authenticate()
        response = self.client.post(
            "/api/v1/users/preferred-tags/",
            {"tag_id": str(self.tag.id), "priority": 2, "notes": "맑은 날 좋아함"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        pref_id = response.data["id"]

        list_response = self.client.get("/api/v1/users/preferred-tags/")
        self.assertEqual(list_response.status_code, status.HTTP_200_OK)
        self.assertEqual(list_response.data["count"], 1)
        self.assertEqual(list_response.data["results"][0]["id"], pref_id)
        self.assertEqual(list_response.data["results"][0]["priority"], 2)

    def test_update_priority(self):
        self.authenticate()
        create = self.client.post(
            "/api/v1/users/preferred-tags/",
            {"tag_id": str(self.tag.id)},
            format="json",
        )
        pref_id = create.data["id"]
        response = self.client.patch(
            f"/api/v1/users/preferred-tags/{pref_id}/",
            {"priority": 3},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["priority"], 3)

    def test_delete_preference(self):
        self.authenticate()
        create = self.client.post(
            "/api/v1/users/preferred-tags/",
            {"tag_id": str(self.tag.id)},
            format="json",
        )
        pref_id = create.data["id"]
        response = self.client.delete(f"/api/v1/users/preferred-tags/{pref_id}/")
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
