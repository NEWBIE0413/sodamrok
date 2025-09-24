from __future__ import annotations

from django.db import models

from lifelog.core.models import TimeStampedModel, UUIDModel


class PartySession(UUIDModel, TimeStampedModel):
    class Status(models.TextChoices):
        PLANNED = "planned", "준비"
        ACTIVE = "active", "진행중"
        COMPLETED = "completed", "완료"

    PRECISION_CHOICES = (
        ("exact", "정확"),
        ("rough", "대략"),
        ("private", "비공개"),
    )

    trip = models.ForeignKey("trips.Trip", on_delete=models.CASCADE, related_name="party_sessions")
    host_user = models.ForeignKey("users.User", on_delete=models.CASCADE, related_name="hosted_sessions")
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PLANNED)
    started_at = models.DateTimeField(null=True, blank=True)
    ended_at = models.DateTimeField(null=True, blank=True)
    sharable_token = models.CharField(max_length=64, unique=True)
    precision = models.CharField(max_length=10, choices=PRECISION_CHOICES, default="private")
    options = models.JSONField(default=dict, blank=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self) -> str:  # pragma: no cover
        return f"Party for {self.trip_id}"


class PartyMember(UUIDModel, TimeStampedModel):
    class Role(models.TextChoices):
        GUIDE = "guide", "길잡이"
        RECORDER = "recorder", "기록가"
        TIMEKEEPER = "timekeeper", "시간지기"
        MEMBER = "member", "일반"

    session = models.ForeignKey(PartySession, on_delete=models.CASCADE, related_name="members")
    user = models.ForeignKey("users.User", on_delete=models.CASCADE, related_name="party_memberships")
    role = models.CharField(max_length=20, choices=Role.choices, default=Role.MEMBER)
    is_active = models.BooleanField(default=True)

    class Meta:
        unique_together = ("session", "user")


class PartyPosition(UUIDModel, TimeStampedModel):
    session = models.ForeignKey(PartySession, on_delete=models.CASCADE, related_name="positions")
    user = models.ForeignKey("users.User", on_delete=models.CASCADE, related_name="positions")
    recorded_at = models.DateTimeField(auto_now_add=True)
    loc = models.JSONField(default=dict, blank=True)
    accuracy_m = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ["-recorded_at"]

