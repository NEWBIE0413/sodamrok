from __future__ import annotations

from rest_framework import permissions, viewsets

from .models import Mission, MissionAssignment
from .serializers import MissionAssignmentSerializer, MissionSerializer


class MissionViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Mission.objects.filter(is_active=True)
    serializer_class = MissionSerializer
    permission_classes = (permissions.IsAuthenticated,)
    filterset_fields = ("badge_type",)
    search_fields = ("title", "description")


class MissionAssignmentViewSet(viewsets.ModelViewSet):
    serializer_class = MissionAssignmentSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        user = self.request.user
        qs = MissionAssignment.objects.select_related("mission", "user")
        if user.is_staff:
            return qs
        return qs.filter(user=user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

