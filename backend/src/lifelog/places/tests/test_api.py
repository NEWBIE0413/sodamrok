from __future__ import annotations

from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

from lifelog.places.models import Place, Tag


class PlaceAPITests(APITestCase):
    def setUp(self):
        super().setUp()
        User = get_user_model()
        self.user = User.objects.create_user(email="user@example.com", password="UserPass123!")
        self.staff = User.objects.create_user(
            email="staff@example.com", password="StaffPass123!", is_staff=True
        )
        self.category_tag = Tag.objects.create(name="cafe", type=Tag.Type.CATEGORY)

    def authenticate(self, email: str, password: str):
        response = self.client.post(
            "/api/auth/token/",
            {"email": email, "password": password},
            format="json",
        )
        token = response.data["access"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")

    def test_anyone_can_retrieve_places(self):
        Place.objects.create(name="Cafe Alpha", category="cafe")
        response = self.client.get("/api/v1/places/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["count"], 1)
        self.assertEqual(len(response.data["results"]), 1)

    def test_non_staff_cannot_create_place(self):
        self.authenticate("user@example.com", "UserPass123!")
        payload = {
            "name": "Cafe Beta",
            "category": "cafe",
            "description": "테스트 카페",
            "tag_ids": [str(self.category_tag.id)],
        }
        response = self.client.post("/api/v1/places/", payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertFalse(Place.objects.filter(name="Cafe Beta").exists())

    def test_staff_can_create_place_with_tags(self):
        self.authenticate("staff@example.com", "StaffPass123!")
        payload = {
            "name": "Cafe Gamma",
            "category": "cafe",
            "description": "조용한 카페",
            "district": "Downtown",
            "tag_ids": [str(self.category_tag.id)],
            "mood_scores": {"calm": 0.9},
        }
        response = self.client.post("/api/v1/places/", payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        created = Place.objects.get(slug=response.data["slug"])
        self.assertEqual(created.tags.count(), 1)
        self.assertEqual(created.tags.first().name, "cafe")

