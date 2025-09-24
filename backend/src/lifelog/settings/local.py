from __future__ import annotations

from .base import *  # noqa

DEBUG = True
ALLOWED_HOSTS = ["127.0.0.1", "localhost"] + ALLOWED_HOSTS
CORS_ALLOW_ALL_ORIGINS = True
CELERY_TASK_ALWAYS_EAGER = True
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

REST_FRAMEWORK["DEFAULT_PERMISSION_CLASSES"] = (
    "rest_framework.permissions.IsAuthenticated",
)

LOGGING["root"]["level"] = "DEBUG"

CHANNEL_LAYERS["default"] = {
    "BACKEND": "channels.layers.InMemoryChannelLayer",
}

