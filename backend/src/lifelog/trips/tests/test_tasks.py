from __future__ import annotations

from django.contrib.auth import get_user_model
from django.test import TestCase

from lifelog.places.models import Place, Tag
from lifelog.trips.models import Trip
from lifelog.trips.tasks import generate_trip_recommendations, sync_trip_freshness


class TripTaskTests(TestCase):
    def setUp(self):
        super().setUp()
        User = get_user_model()
        self.user = User.objects.create_user(email="task@example.com", password="TaskPass123!")

        self.cafe_tag = Tag.objects.create(name="cafe", type=Tag.Type.CATEGORY)
        self.study_tag = Tag.objects.create(name="study", type=Tag.Type.MOOD)

        self.place_a = Place.objects.create(name="Cafe Alpha", category="cafe", rating=4.6, district="downtown")
        self.place_a.tags.add(self.cafe_tag, self.study_tag)
        self.place_b = Place.objects.create(name="Cafe Beta", category="cafe", rating=4.2)
        self.place_b.tags.add(self.cafe_tag)
        self.place_c = Place.objects.create(name="Cafe Gamma", category="cafe", rating=4.0)
        self.place_c.tags.add(self.cafe_tag)

    def test_generate_trip_recommendations_creates_trip_with_nodes(self):
        payload = {
            "time_budget_min": 120,
            "categories": ["cafe"],
            "mood": ["study"],
            "limit": 2,
        }
        result = generate_trip_recommendations.delay(str(self.user.id), payload)
        response = result.result
        self.assertEqual(response["status"], "created")
        self.assertIsNotNone(response["trip_id"])

        trip = Trip.objects.get(id=response["trip_id"])
        self.assertEqual(trip.owner, self.user)
        self.assertEqual(trip.nodes.count(), 2)
        self.assertIn(str(self.place_a.id), trip.summary.get("place_ids", []))

    def test_generate_trip_recommendations_returns_error_when_no_places(self):
        Place.objects.all().delete()
        response = generate_trip_recommendations.delay(str(self.user.id), {"categories": ["museum"]}).result
        self.assertEqual(response["status"], "error")
        self.assertEqual(response["error"], "no_places_available")

    def test_sync_trip_freshness_updates_existing_trip(self):
        trip = Trip.objects.create(context_hash="hash", title="Recommendation Seed")
        trip.freshness_score = 0
        trip.save(update_fields=["freshness_score"])

        result = sync_trip_freshness.delay(str(trip.id))
        self.assertTrue(result.result["updated"])

        trip.refresh_from_db()
        self.assertEqual(trip.freshness_score, 1)

    def test_sync_trip_freshness_handles_missing_trip(self):
        result = sync_trip_freshness.delay("00000000-0000-0000-0000-000000000000")
        self.assertFalse(result.result["updated"])
        self.assertEqual(result.result["error"], "not_found")
