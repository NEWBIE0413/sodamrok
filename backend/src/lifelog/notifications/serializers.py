from __future__ import annotations

from rest_framework import serializers

from .models import Notification, PushSubscription


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = (
            "id",
            "title",
            "body",
            "payload",
            "channel",
            "sent_at",
            "read_at",
            "created_at",
            "updated_at",
        )


class PushSubscriptionSerializer(serializers.ModelSerializer):
    class Meta:
        model = PushSubscription
        fields = (
            "id",
            "endpoint",
            "auth_key",
            "p256dh",
            "metadata",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("created_at", "updated_at")


