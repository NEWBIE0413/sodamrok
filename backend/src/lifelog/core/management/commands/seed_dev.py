from __future__ import annotations

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand
from django.utils.text import slugify

from lifelog.missions.models import Mission
from lifelog.places.models import Place, Tag
from lifelog.trips.services import create_recommendation


class Command(BaseCommand):
    help = "개발 환경용 기본 데이터(태그, 장소, 미션, 데모 사용자)를 생성합니다."

    def handle(self, *args, **options):
        user = self._ensure_demo_user()
        tag_map = self._ensure_tags()
        self._ensure_places(tag_map)
        self._ensure_missions()
        self._ensure_sample_trip(user)
        self.stdout.write(self.style.SUCCESS("개발용 기본 데이터가 준비되었습니다."))

    def _ensure_demo_user(self):
        User = get_user_model()
        user, created = User.objects.get_or_create(
            email="demo@example.com",
            defaults={
                "display_name": "Demo User",
                "nickname": "demo",
            },
        )
        if created:
            user.set_password("DemoPass123!")
            user.save()
            self.stdout.write("- demo@example.com 계정을 생성했습니다 (비밀번호: DemoPass123!)")
        return user

    def _ensure_tags(self) -> dict[str, Tag]:
        tag_definitions = {
            "cafe": Tag.Type.CATEGORY,
            "brunch": Tag.Type.CATEGORY,
            "library": Tag.Type.CATEGORY,
            "calm": Tag.Type.MOOD,
            "sunny": Tag.Type.MOOD,
            "night": Tag.Type.TIME,
        }
        tag_map: dict[str, Tag] = {}
        for name, tag_type in tag_definitions.items():
            tag, created = Tag.objects.get_or_create(name=name, defaults={"type": tag_type})
            if created:
                self.stdout.write(f"- 태그 생성: {name} ({tag_type})")
            tag_map[name] = tag
        return tag_map

    def _ensure_places(self, tag_map: dict[str, Tag]):
        places = [
            {
                "name": "소담 카페",
                "category": "cafe",
                "description": "햇살 좋은 로컬 카페",
                "district": "수원 팔달구",
                "cost_band": "10000-15000",
                "stay_min": 90,
                "mood_scores": {"calm": 0.9, "sunny": 0.7},
                "tags": ["cafe", "calm", "sunny"],
            },
            {
                "name": "정겨운 브런치",
                "category": "brunch",
                "description": "현지 식재료를 쓰는 브런치 카페",
                "district": "수원 영통구",
                "cost_band": "15000-20000",
                "stay_min": 120,
                "mood_scores": {"calm": 0.6},
                "tags": ["brunch", "sunny"],
            },
            {
                "name": "길 위의 도서관",
                "category": "library",
                "description": "산책과 함께 즐기는 작은 도서관",
                "district": "화성 동탄",
                "cost_band": "0",
                "stay_min": 60,
                "mood_scores": {"calm": 0.95},
                "tags": ["library", "calm", "night"],
            },
        ]

        for item in places:
            tags = item["tags"]
            defaults = {k: v for k, v in item.items() if k != "tags"}
            defaults["slug"] = slugify(item["name"])
            place, created = Place.objects.get_or_create(
                slug=defaults["slug"],
                defaults=defaults,
            )
            if not created:
                for field, value in defaults.items():
                    setattr(place, field, value)
                place.save()
            place.tags.set([tag_map[tag_name] for tag_name in tags])
            if created:
                self.stdout.write(f"- 장소 생성: {place.name}")

    def _ensure_missions(self):
        missions = [
            {
                "title": "오늘의 산책 루틴",
                "description": "집 근처 공원이나 문화 공간을 20분 이상 산책해보세요.",
                "steps": ["가벼운 스트레칭", "산책 인증 사진 남기기"],
                "badge_type": "walk",
            },
            {
                "title": "친구와 브런치",
                "description": "친구와 함께 브런치 장소를 찾아 기록을 남겨보세요.",
                "steps": ["친구 초대", "인상 깊었던 메뉴 기록"],
                "badge_type": "social",
            },
        ]
        for data in missions:
            mission, created = Mission.objects.update_or_create(title=data["title"], defaults=data)
            if created:
                self.stdout.write(f"- 미션 생성: {mission.title}")

    def _ensure_sample_trip(self, user):
        try:
            trip = create_recommendation(user.id, {"categories": ["cafe"], "limit": 3})
            self.stdout.write(f"- 추천 코스 샘플 생성: {trip.title}")
        except Exception as exc:  # pragma: no cover - 시드가 이미 있을 때 대비
            self.stdout.write(self.style.WARNING(f"추천 코스 생성을 건너뜀: {exc}"))
