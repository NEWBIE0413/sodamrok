from __future__ import annotations

from rest_framework import serializers

from .models import User


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = (
            "id",
            "email",
            "display_name",
            "nickname",
            "bio",
            "avatar",
            "preferences",
            "onboarded_at",
            "time_budget_min",
            "budget_band",
            "mobility_mode",
            "privacy_level",
            "push_opt_in",
            "location_opt_in",
            "date_joined",
            "last_login",
        )
        read_only_fields = ("id", "email", "date_joined", "last_login", "onboarded_at")


class UserCreateSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = (
            "id",
            "email",
            "password",
            "display_name",
            "nickname",
            "preferences",
            "mobility_mode",
            "time_budget_min",
            "budget_band",
        )

    def create(self, validated_data):
        password = validated_data.pop("password")
        return User.objects.create_user(password=password, **validated_data)


