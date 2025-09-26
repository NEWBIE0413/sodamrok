from __future__ import annotations

from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

from lifelog.places.models import Place, Tag
from lifelog.trips.models import TripTemplate


class TripTemplateAPITests(APITestCase):
    def setUp(self):
        super().setUp()
        User = get_user_model()
        self.staff = User.objects.create_user(email="staff@example.com", password="StaffPass123!", is_staff=True)
        self.member = User.objects.create_user(email="member@example.com", password="MemberPass123!")
        self.tag = Tag.objects.create(name="calm", type=Tag.Type.MOOD)
        self.place = Place.objects.create(name="Seowon Library", category="library", stay_min=40)
        self.place.tags.add(self.tag)

    def authenticate(self, email: str, password: str):
        response = self.client.post(
            "/api/auth/token/",
            {"email": email, "password": password},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        token = response.data["access"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")

    def test_staff_can_create_template(self):
        self.authenticate("staff@example.com", "StaffPass123!")
        payload = {
            "title": "도심 속 힐링 루트",
            "summary": "조용한 공간 2곳",
            "description": "에디터가 엄선한 코스",
            "duration_min": 120,
            "is_published": True,
            "nodes": [
                {"place": str(self.place.id), "sequence": 1, "stay_min": 40},
            ],
            "tag_ids": [str(self.tag.id)],
        }
        response = self.client.post("/api/v1/trip-templates/", payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        template = TripTemplate.objects.get(id=response.data["id"])
        self.assertTrue(template.is_published)
        self.assertEqual(template.nodes.count(), 1)

    def test_non_staff_sees_only_published_templates(self):
        TripTemplate.objects.create(title="비공개", is_published=False)
        TripTemplate.objects.create(title="공개", is_published=True)
        self.authenticate("member@example.com", "MemberPass123!")
        response = self.client.get("/api/v1/trip-templates/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        results = response.data.get("results", [])
        titles = {item["title"] for item in results}
        self.assertIn("공개", titles)
        self.assertNotIn("비공개", titles)

    def test_member_can_instantiate_template(self):
        template = TripTemplate.objects.create(title="공개 코스", is_published=True, duration_min=60)
        template.tags.add(self.tag)
        template.nodes.create(place=self.place, sequence=1, stay_min=30)
        self.authenticate("member@example.com", "MemberPass123!")
        response = self.client.post(
            "/api/v1/trips/from-template/",
            {"template_id": str(template.id), "title": "주말 코스"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(len(response.data["nodes"]), 1)
        self.assertEqual(response.data["title"], "주말 코스")
