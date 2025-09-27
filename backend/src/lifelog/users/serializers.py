from __future__ import annotations

from django.contrib.auth import password_validation
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from lifelog.places.serializers import TagSerializer
from lifelog.places.models import Tag

from .models import User, UserBadge, UserPreferredTag, UserStamp


class UserPreferredTagSerializer(serializers.ModelSerializer):
    tag = TagSerializer(read_only=True)
    tag_id = serializers.UUIDField(write_only=True)

    class Meta:
        model = UserPreferredTag
        fields = ("id", "tag", "tag_id", "priority", "notes", "created_at")
        read_only_fields = ("id", "tag", "created_at")

    def validate_tag_id(self, value):
        if not Tag.objects.filter(id=value).exists():
            raise serializers.ValidationError("Tag does not exist.")
        return value

    def create(self, validated_data):
        tag_id = validated_data.pop("tag_id")
        tag = Tag.objects.get(id=tag_id)
        user = validated_data.pop("user", None) or self.context["request"].user
        defaults = {"priority": validated_data.get("priority", 1), "notes": validated_data.get("notes", "")}
        preferred, _ = UserPreferredTag.objects.update_or_create(
            user=user,
            tag=tag,
            defaults=defaults,
        )
        return preferred

    def update(self, instance, validated_data):
        if "tag_id" in validated_data:
            raise serializers.ValidationError({"tag_id": "Cannot change tag."})
        if "user" in validated_data:
            raise serializers.ValidationError({"user": "Cannot reassign preference owner."})
        instance.priority = validated_data.get("priority", instance.priority)
        instance.notes = validated_data.get("notes", instance.notes)
        instance.save(update_fields=["priority", "notes"])
        return instance


class UserSerializer(serializers.ModelSerializer):
    preferred_tags = UserPreferredTagSerializer(many=True, read_only=True)
    stamps = serializers.SerializerMethodField()
    badges = serializers.SerializerMethodField()

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
            "preferred_tags",
            "onboarded_at",
            "time_budget_min",
            "budget_band",
            "mobility_mode",
            "privacy_level",
            "push_opt_in",
            "location_opt_in",
            "profile_token_balance",
            "stamps",
            "badges",
            "date_joined",
            "last_login",
        )
        read_only_fields = (
            "id",
            "email",
            "date_joined",
            "last_login",
            "onboarded_at",
            "profile_token_balance",
            "stamps",
            "badges",
        )

    def get_stamps(self, obj: User) -> list[str]:
        return list(obj.stamps.values_list("code", flat=True))

    def get_badges(self, obj: User) -> list[str]:
        return list(obj.badges.values_list("code", flat=True))


class PasswordResetSerializer(serializers.Serializer):
    email = serializers.EmailField()
    new_password = serializers.CharField(write_only=True, min_length=8)

    def validate_email(self, value: str) -> str:
        if not User.objects.filter(email=value).exists():
            raise serializers.ValidationError("등록된 이메일과 일치하는 사용자가 없습니다.")
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
    """JWT 발급 시 사용자 정보도 함께 반환하는 직렬화기."""

    def validate(self, attrs):
        data = super().validate(attrs)
        data["user"] = UserSerializer(self.user, context=self.context).data
        return data
