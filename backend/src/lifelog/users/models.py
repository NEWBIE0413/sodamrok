from __future__ import annotations

from django.contrib.auth.base_user import BaseUserManager
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin
from django.db import models
from django.utils import timezone

from lifelog.core.models import TimeStampedModel, UUIDModel


class UserManager(BaseUserManager):
    use_in_migrations = True

    def _create_user(self, email: str, password: str | None, **extra_fields):
        if not email:
            raise ValueError("Users must provide an email address.")
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_user(self, email: str, password: str | None = None, **extra_fields):
        extra_fields.setdefault("is_staff", False)
        extra_fields.setdefault("is_superuser", False)
        extra_fields.setdefault("is_active", True)
        return self._create_user(email, password, **extra_fields)

    def create_superuser(self, email: str, password: str, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_active", True)
        extra_fields.setdefault("privacy_level", self.model.PrivacyLevel.FRIENDS.value)

        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superuser must have is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_superuser=True.")
        return self._create_user(email, password, **extra_fields)


class User(UUIDModel, TimeStampedModel, AbstractBaseUser, PermissionsMixin):
    class PrivacyLevel(models.TextChoices):
        PRIVATE = "private", "비공개"
        FRIENDS = "friends", "친구만"
        PUBLIC = "public", "전체공개"

    class MobilityMode(models.TextChoices):
        WALK = "walk", "도보"
        TRANSIT = "transit", "대중교통"
        BIKE = "bike", "자전거"
        DRIVE = "drive", "자가용"

    email = models.EmailField(unique=True)
    display_name = models.CharField(max_length=80, blank=True)
    nickname = models.CharField(max_length=40, blank=True)
    bio = models.TextField(blank=True)
    avatar = models.URLField(blank=True)

    onboarded_at = models.DateTimeField(null=True, blank=True)
    time_budget_min = models.PositiveIntegerField(default=120, help_text="선호하는 체류 시간 예산(분)")
    budget_band = models.CharField(max_length=30, blank=True)
    mobility_mode = models.CharField(
        max_length=16,
        choices=MobilityMode.choices,
        default=MobilityMode.WALK,
    )
    privacy_level = models.CharField(
        max_length=16,
        choices=PrivacyLevel.choices,
        default=PrivacyLevel.PRIVATE,
    )

    preferences = models.JSONField(default=dict, blank=True)
    push_opt_in = models.BooleanField(default=True)
    location_opt_in = models.BooleanField(default=False)

    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)

    date_joined = models.DateTimeField(default=timezone.now)

    objects = UserManager()

    EMAIL_FIELD = "email"
    USERNAME_FIELD = "email"
    REQUIRED_FIELDS: list[str] = []

    class Meta:
        ordering = ["-date_joined"]
        indexes = [
            models.Index(fields=["email"]),
        ]

    def __str__(self) -> str:  # pragma: no cover - human readable helper
        return self.display_name or self.email

    def mark_onboarded(self):
        self.onboarded_at = timezone.now()
        self.save(update_fields=["onboarded_at"])

class UserPreferredTag(TimeStampedModel):
    user = models.ForeignKey("users.User", on_delete=models.CASCADE, related_name="preferred_tags")
    tag = models.ForeignKey("places.Tag", on_delete=models.CASCADE, related_name="preferred_by")
    priority = models.PositiveSmallIntegerField(default=1)
    notes = models.CharField(max_length=120, blank=True)

    class Meta:
        unique_together = ("user", "tag")
        ordering = ("-priority", "-created_at")

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.user_id}:{self.tag_id}"

