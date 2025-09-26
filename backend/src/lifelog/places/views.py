from __future__ import annotations

from django.db.models import Q
from rest_framework import permissions, viewsets

from .models import FavoritePlace, Place, Tag
from .serializers import FavoritePlaceSerializer, PlaceSerializer, PlaceWriteSerializer, TagSerializer


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



class FavoritePlaceViewSet(viewsets.ModelViewSet):
    queryset = FavoritePlace.objects.none()
    serializer_class = FavoritePlaceSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        return FavoritePlace.objects.filter(user=self.request.user).select_related("place").order_by("-created_at")

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    def perform_destroy(self, instance):
        if instance.user != self.request.user and not self.request.user.is_staff:
            raise permissions.PermissionDenied("Cannot remove another user's favorite.")
        super().perform_destroy(instance)
