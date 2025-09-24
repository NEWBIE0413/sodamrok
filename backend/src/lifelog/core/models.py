from __future__ import annotations

import uuid

from django.db import models


class UUIDModel(models.Model):
    """Abstract model that provides a UUID primary key."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    class Meta:
        abstract = True


class TimeStampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


class SoftDeleteQuerySet(models.QuerySet):
    def alive(self):
        return self.filter(is_active=True)

    def deleted(self):
        return self.filter(is_active=False)


class SoftDeleteModel(models.Model):
    is_active = models.BooleanField(default=True)

    objects = SoftDeleteQuerySet.as_manager()

    class Meta:
        abstract = True

    def delete(self, using=None, keep_parents=False):  # type: ignore[override]
        self.is_active = False
        self.save(update_fields=["is_active"])

