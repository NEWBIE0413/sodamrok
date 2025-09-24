from __future__ import annotations

from rest_framework import permissions, viewsets

from .models import Trip
from .serializers import TripSerializer, TripWriteSerializer


class TripViewSet(viewsets.ModelViewSet):
    permission_classes = (permissions.IsAuthenticated,)
    ordering = ("-created_at",)

    def get_queryset(self):
        user = self.request.user
        qs = Trip.objects.prefetch_related("nodes__place")
        if user.is_staff:
            return qs
        return qs.filter(owner=user)

    def get_serializer_class(self):
        if self.action in {"create", "update", "partial_update"}:
            return TripWriteSerializer
        return TripSerializer

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)

