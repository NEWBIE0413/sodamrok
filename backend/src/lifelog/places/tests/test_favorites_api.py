from __future__ import annotations

from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

from lifelog.places.models import FavoritePlace, Place


class FavoritePlaceAPITests(APITestCase):
    def setUp(self):
        super().setUp()
        User = get_user_model()
        self.user = User.objects.create_user(email="fan@example.com", password="FanPass123!")
        self.other = User.objects.create_user(email="other@example.com", password="OtherPass123!")
        self.place = Place.objects.create(name="Hidden Cafe", category="cafe", stay_min=30)

    def authenticate(self, email: str, password: str):
        response = self.client.post(
            "/api/auth/token/",
            {"email": email, "password": password},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {response.data['access']}")

    def test_user_can_create_and_list_favorites(self):
        self.authenticate("fan@example.com", "FanPass123!")
        response = self.client.post(
            "/api/v1/favorites/places/",
            {"place_id": str(self.place.id), "note": "주말 코스"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        favorite_id = response.data["id"]

        list_response = self.client.get("/api/v1/favorites/places/")
        self.assertEqual(list_response.status_code, status.HTTP_200_OK)
        self.assertEqual(list_response.data["count"], 1)
        self.assertEqual(list_response.data["results"][0]["id"], favorite_id)

    def test_duplicate_create_updates_note(self):
        self.authenticate("fan@example.com", "FanPass123!")
        for note in ("첫 방문", "재방문"):
            response = self.client.post(
                "/api/v1/favorites/places/",
                {"place_id": str(self.place.id), "note": note},
                format="json",
            )
            self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        favorite = FavoritePlace.objects.get(user=self.user, place=self.place)
        self.assertEqual(favorite.note, "재방문")

    def test_user_can_update_note(self):
        FavoritePlace.objects.create(user=self.user, place=self.place, note="초기")
        self.authenticate("fan@example.com", "FanPass123!")
        favorite = FavoritePlace.objects.get(user=self.user, place=self.place)
        response = self.client.patch(
            f"/api/v1/favorites/places/{favorite.id}/",
            {"note": "수정"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        favorite.refresh_from_db()
        self.assertEqual(favorite.note, "수정")

    def test_user_cannot_delete_others_favorite(self):
        favorite = FavoritePlace.objects.create(user=self.other, place=self.place, note="타인")
        self.authenticate("fan@example.com", "FanPass123!")
        response = self.client.delete(f"/api/v1/favorites/places/{favorite.id}/")
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
