from __future__ import annotations

from django.test import TestCase

from lifelog.places.models import Place
from lifelog.places.tasks import refresh_place_metadata


class PlaceTaskTests(TestCase):
    def setUp(self):
        super().setUp()
        self.place = Place.objects.create(name="Local Cafe", category="cafe")

    def test_refresh_place_metadata_updates_mood_scores(self):
        result = refresh_place_metadata.delay(
            str(self.place.id),
            {"mood_scores": {"calm": 0.8, "vibrant": 0.2}},
        )
        self.assertTrue(result.result["updated"])
        self.place.refresh_from_db()
        self.assertEqual(self.place.mood_scores.get("calm"), 0.8)

    def test_refresh_place_metadata_handles_missing_place(self):
        result = refresh_place_metadata.delay(
            "00000000-0000-0000-0000-000000000000",
            {"mood_scores": {"calm": 1.0}},
        )
        self.assertFalse(result.result["updated"])
        self.assertEqual(result.result["error"], "not_found")
