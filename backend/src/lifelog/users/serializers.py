from __future__ import annotations

from django.contrib.auth import password_validation
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

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


class PasswordResetSerializer(serializers.Serializer):
    email = serializers.EmailField()
    new_password = serializers.CharField(write_only=True, min_length=8)

    def validate_email(self, value: str) -> str:
        if not User.objects.filter(email=value).exists():
            raise serializers.ValidationError("입력한 이메일과 일치하는 사용자가 없습니다.")
        return value

    def validate_new_password(self, value: str) -> str:
        password_validation.validate_password(value)
        return value

    def save(self, **kwargs):
        email = self.validated_data["email"]
        new_password = self.validated_data["new_password"]
        user = User.objects.get(email=email)
        password_validation.validate_password(new_password, user)
        user.set_password(new_password)
        user.save(update_fields=["password"])
        return user


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

    def validate_password(self, value: str) -> str:
        password_validation.validate_password(value)
        return value

    def create(self, validated_data):
        password = validated_data.pop("password")
        password_validation.validate_password(password)
        return User.objects.create_user(password=password, **validated_data)


class UserTokenObtainPairSerializer(TokenObtainPairSerializer):
    """JWT 발급 시 사용자 프로필을 함께 반환하는 직렬화기."""

    def validate(self, attrs):
        data = super().validate(attrs)
        data["user"] = UserSerializer(self.user, context=self.context).data
        return data

