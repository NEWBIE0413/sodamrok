from __future__ import annotations

from django.db import models

from lifelog.core.models import TimeStampedModel, UUIDModel


class Notification(UUIDModel, TimeStampedModel):
    class Channel(models.TextChoices):
        PUSH = "push", "푸시"
        EMAIL = "email", "이메일"
        INAPP = "inapp", "앱 내"

    user = models.ForeignKey("users.User", on_delete=models.CASCADE, related_name="notifications")
    title = models.CharField(max_length=140)
    body = models.TextField()
    payload = models.JSONField(default=dict, blank=True)
    channel = models.CharField(max_length=20, choices=Channel.choices, default=Channel.PUSH)
    sent_at = models.DateTimeField(null=True, blank=True)
    read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]

    def mark_read(self):
        from django.utils import timezone

        self.read_at = timezone.now()
        self.save(update_fields=["read_at"])


class PushSubscription(UUIDModel, TimeStampedModel):
    user = models.ForeignKey("users.User", on_delete=models.CASCADE, related_name="push_subscriptions")
    endpoint = models.CharField(max_length=500)
    auth_key = models.CharField(max_length=120)
    p256dh = models.CharField(max_length=120)
    metadata = models.JSONField(default=dict, blank=True)

    class Meta:
        unique_together = ("user", "endpoint")

