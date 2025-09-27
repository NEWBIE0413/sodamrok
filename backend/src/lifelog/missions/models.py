from __future__ import annotations

from django.db import models
from django.utils import timezone

from lifelog.core.models import TimeStampedModel, UUIDModel


class Mission(UUIDModel, TimeStampedModel):
    class Frequency(models.TextChoices):
        ADHOC = "adhoc", "Ad-hoc"
        DAILY = "daily", "Daily"

    class RewardType(models.TextChoices):
        CURRENCY = "currency", "Currency"
        STAMP = "stamp", "Stamp"
        BADGE = "badge", "Badge"

    title = models.CharField(max_length=140)
    description = models.TextField(blank=True)
    steps = models.JSONField(default=list, blank=True)
    badge_type = models.CharField(max_length=60, blank=True)
    frequency = models.CharField(max_length=20, choices=Frequency.choices, default=Frequency.ADHOC)
    reward_type = models.CharField(max_length=20, choices=RewardType.choices, default=RewardType.CURRENCY)
    reward_code = models.CharField(max_length=80, blank=True)
    reward_amount = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ["title"]

    def __str__(self) -> str:  # pragma: no cover
        return self.title


class MissionAssignment(UUIDModel, TimeStampedModel):
    class Status(models.TextChoices):
        PENDING = "pending", "대기"
        COMPLETED = "completed", "완료"
        EXPIRED = "expired", "만료"

    user = models.ForeignKey("users.User", on_delete=models.CASCADE, related_name="mission_assignments")
    mission = models.ForeignKey(Mission, on_delete=models.CASCADE, related_name="assignments")
    assigned_at = models.DateTimeField(auto_now_add=True)
    date_for = models.DateField(null=True, blank=True)
    due_at = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    result_metadata = models.JSONField(default=dict, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    reward_granted = models.BooleanField(default=False)

    class Meta:
        unique_together = (("user", "mission", "date_for"),)

    def mark_completed(self, metadata: dict | None = None):
        self.status = self.Status.COMPLETED
        self.completed_at = timezone.now()
        if metadata:
            merged = {**self.result_metadata, **metadata}
            self.result_metadata = merged
        self.save(update_fields=["status", "completed_at", "result_metadata"])


class MissionRewardLog(UUIDModel, TimeStampedModel):
    assignment = models.OneToOneField(MissionAssignment, on_delete=models.CASCADE, related_name="reward_log")
    reward_type = models.CharField(max_length=20, choices=Mission.RewardType.choices)
    reward_code = models.CharField(max_length=80, blank=True)
    reward_amount = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self) -> str:  # pragma: no cover
        return f"Reward({self.reward_type}) for {self.assignment_id}"
