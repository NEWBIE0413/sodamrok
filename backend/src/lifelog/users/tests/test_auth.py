from __future__ import annotations

from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase


class UserAuthTests(APITestCase):
    def setUp(self):
        super().setUp()
        self.user_url = "/api/v1/users/"
        self.token_url = "/api/auth/token/"
        self.refresh_url = "/api/auth/token/refresh/"
        self.me_url = "/api/v1/users/me/"

    def test_user_registration_creates_account(self):
        payload = {
            "email": "newuser@example.com",
            "password": "securepass123",
            "display_name": "New User",
            "time_budget_min": 120,
            "mobility_mode": "walk",
        }
        response = self.client.post(self.user_url, payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        user_model = get_user_model()
        self.assertTrue(user_model.objects.filter(email=payload["email"]).exists())
        self.assertNotIn("password", response.data)

    def test_token_obtain_and_refresh_flow(self):
        user_model = get_user_model()
        user_model.objects.create_user(email="auth@example.com", password="AuthPass123!")

        response = self.client.post(
            self.token_url,
            {"email": "auth@example.com", "password": "AuthPass123!"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        access = response.data.get("access")
        refresh = response.data.get("refresh")
        self.assertTrue(access)
        self.assertTrue(refresh)

        refresh_response = self.client.post(
            self.refresh_url,
            {"refresh": refresh},
            format="json",
        )
        self.assertEqual(refresh_response.status_code, status.HTTP_200_OK)
        self.assertIn("access", refresh_response.data)

    def test_me_endpoint_allows_view_and_update(self):
        user_model = get_user_model()
        user = user_model.objects.create_user(
            email="profile@example.com", password="ProfilePass!23", display_name="Profile"
        )

        token_response = self.client.post(
            self.token_url,
            {"email": "profile@example.com", "password": "ProfilePass!23"},
            format="json",
        )
        access = token_response.data["access"]

        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
        response = self.client.get(self.me_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["email"], "profile@example.com")

        patch_response = self.client.patch(
            self.me_url,
            {"display_name": "Updated"},
            format="json",
        )
        self.assertEqual(patch_response.status_code, status.HTTP_200_OK)
        self.assertEqual(patch_response.data["display_name"], "Updated")

        user.refresh_from_db()
        self.assertEqual(user.display_name, "Updated")

