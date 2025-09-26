from __future__ import annotations

from django.test import TestCase

from lifelog.places.models import Place, Tag
from lifelog.trips.models import Trip
from lifelog.trips.services import NoPlacesAvailableError, create_recommendation


class TripRecommendationServiceTests(TestCase):
    def setUp(self):
        self.calm_tag = Tag.objects.create(name="calm", type=Tag.Type.MOOD)
        self.focus_tag = Tag.objects.create(name="focus", type=Tag.Type.MOOD)

        self.calm_cafe = Place.objects.create(
            name="Calm Cafe",
            category="cafe",
            cost_band="8000-12000",
            stay_min=45,
            district="수원 팔달구",
            mood_scores={"calm": 0.9, "focus": 0.4},
            rating=4.6,
        )
        self.calm_cafe.tags.add(self.calm_tag)

        self.gallery = Place.objects.create(
            name="Gallery Walk",
            category="culture",
            cost_band="무료",
            stay_min=40,
            district="수원 팔달구",
            mood_scores={"calm": 0.5},
            rating=4.2,
        )
        self.gallery.tags.add(self.calm_tag)

        self.rooftop = Place.objects.create(
            name="Rooftop Lounge",
            category="cafe",
            cost_band="25000",
            stay_min=75,
            district="수원 장안구",
            mood_scores={"calm": 0.3, "focus": 0.6},
            rating=4.8,
        )
        self.rooftop.tags.add(self.focus_tag)

    def test_filters_by_budget_mood_and_district(self):
        trip = create_recommendation(
            None,
            {
                "categories": ["cafe"],
                "mood": ["calm"],
                "district": "수원 팔달구",
                "budget_max": 15000,
                "time_budget_min": 120,
            },
        )

        nodes = list(trip.nodes.order_by("sequence"))
        self.assertEqual(len(nodes), 1)
        self.assertEqual(nodes[0].place, self.calm_cafe)
        self.assertIn(str(self.calm_cafe.id), trip.summary["place_ids"])

    def test_time_budget_limits_number_of_stops(self):
        trip = create_recommendation(
            None,
            {
                "categories": ["cafe", "culture"],
                "time_budget_min": 60,
                "limit": 3,
                "budget_max": 40000,
            },
        )

        nodes = list(trip.nodes.order_by("sequence"))
        self.assertEqual(len(nodes), 1)
        self.assertEqual(nodes[0].place, self.calm_cafe)

    def test_no_places_available_raises(self):
        skip_all = [str(self.calm_cafe.id), str(self.gallery.id), str(self.rooftop.id)]
        with self.assertRaises(NoPlacesAvailableError):
            create_recommendation(
                None,
                {
                    "categories": ["cafe"],
                    "skip_place_ids": skip_all,
                    "limit": 2,
                },
            )



