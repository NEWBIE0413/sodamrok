from __future__ import annotations

import json
from unittest import mock

from django.contrib.auth import get_user_model
from django.test import override_settings
from rest_framework import status
from rest_framework.test import APITestCase

from lifelog.places.models import Place
from lifelog.trips.models import TripTemplateGenerationJob
from lifelog.trips.tasks import request_ai_template


class TripTemplateGenerationJobAPITests(APITestCase):
    def setUp(self):
        super().setUp()
        User = get_user_model()
        self.user = User.objects.create_user(email="job@example.com", password="JobPass123!")
        token_response = self.client.post(
            "/api/auth/token/",
            {"email": "job@example.com", "password": "JobPass123!"},
            format="json",
        )
        self.assertEqual(token_response.status_code, status.HTTP_200_OK)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token_response.data['access']}")
        self.delay_patcher = mock.patch("lifelog.trips.views.request_ai_template.delay")
        self.mock_delay = self.delay_patcher.start()
        self.addCleanup(self.delay_patcher.stop)

    def test_create_ai_job_enqueues_task(self):
        payload = {
            "brief": "수원 인근에서 오후에 즐길 잔잔한 감성 공간 위주로 부탁해",
            "location": "수원시 팔달구",
            "mood_tags": ["calm", "minimal"],
            "duration_min": 240,
            "stops": 3,
        }
        response = self.client.post("/api/v1/trip-template-ai-jobs/", payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        job_id = response.data["id"]
        self.mock_delay.assert_called_once_with(job_id)
        job = TripTemplateGenerationJob.objects.get(id=job_id)
        self.assertEqual(job.status, TripTemplateGenerationJob.Status.QUEUED)
        self.assertEqual(job.prompt["brief"], payload["brief"])

    def test_list_returns_only_authenticated_users_jobs(self):
        other_user = get_user_model().objects.create_user(email="other@example.com", password="OtherPass123!")
        TripTemplateGenerationJob.objects.create(requested_by=other_user, prompt={"brief": "다른 사람"})
        own_job = TripTemplateGenerationJob.objects.create(requested_by=self.user, prompt={"brief": "나의 여행"})
        response = self.client.get("/api/v1/trip-template-ai-jobs/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = [item["id"] for item in response.data.get("results", [])]
        self.assertIn(str(own_job.id), ids)
        self.assertNotIn(str(TripTemplateGenerationJob.objects.exclude(id=own_job.id).first().id), ids)


class TripTemplateGenerationJobTaskTests(APITestCase):
    def setUp(self):
        super().setUp()
        self.job = TripTemplateGenerationJob.objects.create(
            prompt={
                "brief": "카페와 전통시장 조합",
                "location": "수원",
                "mood_tags": ["warm"],
                "duration_min": 180,
                "stops": 3,
            }
        )
        Place.objects.create(name="팔달문시장", category="market")

    @override_settings(
        OPENROUTER={
            "api_key": "test-key",
            "base_url": "https://openrouter.ai/api/v1",
            "model": "openrouter/test-model",
            "app_url": "https://sodamrok.example",
            "timeout": 5,
        }
    )
    @mock.patch("lifelog.core.clients.openrouter.httpx.Client")
    def test_request_ai_template_success(self, mock_client_cls):
        mock_client = mock.MagicMock()
        mock_response = mock.MagicMock()
        payload = {
            "title": "수원 감성 산책",
            "summary": "카페와 시장을 잇는 오후 감성 동선",
            "duration_min": 200,
            "mood_tags": ["warm", "cozy"],
            "stops": [
                {
                    "name": "팔달문시장",
                    "description": "로컬 먹거리와 소품을 둘러보는 시간",
                    "stay_min": 50,
                    "category": "market",
                },
                {
                    "name": "카페 무드",
                    "description": "감성 가득한 디저트와 휴식",
                    "stay_min": 60,
                },
            ],
            "tips": "여유 있게 걷고, 시장 안 맛집을 미리 체크하세요.",
        }
        mock_response.json.return_value = {
            "choices": [
                {
                    "message": {
                        "content": json.dumps(payload, ensure_ascii=False)
                    }
                }
            ]
        }
        mock_client.post.return_value = mock_response
        mock_client.__enter__.return_value = mock_client
        mock_client.__exit__.return_value = False
        mock_client_cls.return_value = mock_client

        result = request_ai_template.delay(str(self.job.id)).result

        self.job.refresh_from_db()
        self.assertEqual(result["status"], "completed")
        self.assertEqual(self.job.status, TripTemplateGenerationJob.Status.COMPLETED)
        self.assertEqual(self.job.result["title"], payload["title"])
        first_stop = self.job.result["stops"][0]
        self.assertIn("place_id", first_stop)

    def test_request_ai_template_handles_missing_configuration(self):
        response = request_ai_template.delay(str(self.job.id)).result
        self.job.refresh_from_db()
        self.assertEqual(response["status"], "error")
        self.assertEqual(self.job.status, TripTemplateGenerationJob.Status.FAILED)
        self.assertEqual(self.job.error_code, "openrouter_not_configured")
