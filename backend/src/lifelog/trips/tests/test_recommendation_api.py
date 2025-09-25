from __future__ import annotations

from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

from lifelog.places.models import Place, Tag


class TripRecommendationAPITests(APITestCase):
    def setUp(self):
        super().setUp()
        User = get_user_model()
        self.user = User.objects.create_user(email="api@example.com", password="ApiPass123!")
        self.token = self.client.post(
            "/api/auth/token/",
            {"email": "api@example.com", "password": "ApiPass123!"},
            format="json",
        ).data["access"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {self.token}")

        self.cafe_tag = Tag.objects.create(name="cafe", type=Tag.Type.CATEGORY)
        self.mood_tag = Tag.objects.create(name="calm", type=Tag.Type.MOOD)

        self.place1 = Place.objects.create(name="Cafe One", category="cafe", rating=4.5)
        self.place1.tags.add(self.cafe_tag, self.mood_tag)
        self.place2 = Place.objects.create(name="Cafe Two", category="cafe", rating=4.3)
        self.place2.tags.add(self.cafe_tag)

    def test_recommendations_endpoint_returns_trip(self):
        payload = {
            "categories": ["cafe"],
            "mood": ["calm"],
            "limit": 2,
            "time_budget_min": 90,
        }
        response = self.client.post("/api/v1/trips/recommendations/", payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(len(response.data["nodes"]), 2)
        self.assertEqual(response.data["mode"], "walk")

    def test_recommendations_returns_error_when_no_places(self):
        Place.objects.all().delete()
        response = self.client.post(
            "/api/v1/trips/recommendations/",
            {"categories": ["museum"]},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.data["error"], "no_places_available")
