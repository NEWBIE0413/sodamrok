from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.utils.translation import gettext_lazy as _

from .models import User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    ordering = ("email",)
    list_display = ("email", "display_name", "is_staff", "is_active")
    list_filter = ("is_staff", "is_active", "privacy_level")
    search_fields = ("email", "display_name", "nickname")
    fieldsets = (
        (_("Account"), {"fields": ("email", "password", "display_name", "nickname", "bio", "avatar")}),
        (
            _("Preferences"),
            {
                "fields": (
                    "onboarded_at",
                    "time_budget_min",
                    "budget_band",
                    "mobility_mode",
                    "privacy_level",
                    "preferences",
                    "push_opt_in",
                    "location_opt_in",
                )
            },
        ),
        (_("Permissions"), {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")}),
        (_("Important dates"), {"fields": ("last_login", "date_joined")}),
    )
    add_fieldsets = (
        (
            None,
            {
                "classes": ("wide",),
                "fields": ("email", "password1", "password2", "display_name", "is_staff", "is_superuser"),
            },
        ),
    )
