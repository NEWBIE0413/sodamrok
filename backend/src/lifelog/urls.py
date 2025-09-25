from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView
from rest_framework_simplejwt.views import TokenRefreshView

from lifelog.users.views import PasswordResetView, UserTokenObtainPairView

urlpatterns = [
    path(settings.ADMIN_URL, admin.site.urls),
    path("api/auth/token/", UserTokenObtainPairView.as_view(), name="token-obtain"),
    path("api/auth/reset-password/", PasswordResetView.as_view(), name="password-reset"),
    path("api/auth/token/refresh/", TokenRefreshView.as_view(), name="token-refresh"),
    path("api/schema/", SpectacularAPIView.as_view(), name="api-schema"),
    path(
        "api/docs/",
        SpectacularSwaggerView.as_view(url_name="api-schema"),
        name="api-docs",
    ),
    path("api/v1/", include("lifelog.api_router")),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
