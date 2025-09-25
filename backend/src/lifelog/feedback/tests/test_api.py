from __future__ import annotations

from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

from lifelog.feedback.models import Feedback
from lifelog.places.models import Place
from lifelog.trips.models import Trip, TripNode


class FeedbackAPITests(APITestCase):
    def setUp(self):
        super().setUp()
        User = get_user_model()
        self.user = User.objects.create_user(email="owner@example.com", password="OwnerPass!23")
        self.other = User.objects.create_user(email="other@example.com", password="OtherPass!23")

        self.place = Place.objects.create(name="Cafe Alpha", category="cafe")
        self.trip = Trip.objects.create(
            owner=self.user,
            title="추천 코스",
            context_hash="hash",
            duration_min=90,
            budget_min=0,
            budget_max=0,
            mode=Trip.Mode.WALK,
        )
        self.node = TripNode.objects.create(trip=self.trip, place=self.place, sequence=1)

    def authenticate(self, email: str, password: str):
        response = self.client.post(
            "/api/auth/token/",
            {"email": email, "password": password},
            format="json",
        )
        token = response.data["access"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")

    def test_user_can_submit_feedback_for_owned_trip(self):
        self.authenticate("owner@example.com", "OwnerPass!23")
        payload = {
            "trip": str(self.trip.id),
            "trip_node": str(self.node.id),
            "rating": Feedback.Rating.GOOD,
            "stay_actual_min": 80,
            "comments": "좋았어요",
        }
        response = self.client.post("/api/v1/feedback/", payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Feedback.objects.count(), 1)

    def test_trip_node_mismatch_returns_error(self):
        other_trip = Trip.objects.create(
            owner=self.user,
            title="다른 코스",
            context_hash="hash2",
            duration_min=60,
            budget_min=0,
            budget_max=0,
            mode=Trip.Mode.WALK,
        )
        other_node = TripNode.objects.create(trip=other_trip, place=self.place, sequence=1)
        self.authenticate("owner@example.com", "OwnerPass!23")
        payload = {
            "trip": str(self.trip.id),
            "trip_node": str(other_node.id),
            "rating": Feedback.Rating.GOOD,
        }
        response = self.client.post("/api/v1/feedback/", payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("trip_node", response.data)

    def test_other_user_cannot_submit_feedback_for_trip(self):
        self.authenticate("other@example.com", "OtherPass!23")
        payload = {
            "trip": str(self.trip.id),
            "rating": Feedback.Rating.GOOD,
        }
        response = self.client.post("/api/v1/feedback/", payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("trip", response.data)
