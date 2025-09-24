from __future__ import annotations

from django.db.models import Q
from rest_framework import permissions, viewsets

from .models import Place, Tag
from .serializers import PlaceSerializer, PlaceWriteSerializer, TagSerializer


class IsAdminOrReadOnly(permissions.BasePermission):
    def has_permission(self, request, view):
        if request.method in permissions.SAFE_METHODS:
            return True
        return request.user and request.user.is_staff


class TagViewSet(viewsets.ModelViewSet):
    queryset = Tag.objects.all()
    serializer_class = TagSerializer
    permission_classes = (IsAdminOrReadOnly,)
    filterset_fields = ("type",)
    search_fields = ("name",)


class PlaceViewSet(viewsets.ModelViewSet):
    queryset = Place.objects.filter(is_active=True)
    permission_classes = (IsAdminOrReadOnly,)
    filterset_fields = (
        "category",
        "district",
        "tags__name",
        "tags__type",
    )
    search_fields = ("name", "district", "description", "tags__name")
    ordering_fields = ("rating", "congestion_score", "updated_at")
    lookup_field = "slug"

    def get_serializer_class(self):
        if self.action in {"create", "update", "partial_update"}:
            return PlaceWriteSerializer
        return PlaceSerializer

    def get_queryset(self):
        qs = super().get_queryset()
        query = self.request.query_params.get("q")
        if query:
            qs = qs.filter(
                Q(name__icontains=query)
                | Q(description__icontains=query)
                | Q(tags__name__icontains=query)
            ).distinct()
        return qs

