from __future__ import annotations

from django.utils import timezone
from rest_framework import permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import Mission, MissionAssignment
from .serializers import MissionAssignmentSerializer, MissionSerializer
from . import services


class MissionViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Mission.objects.filter(is_active=True)
    serializer_class = MissionSerializer
    permission_classes = (permissions.IsAuthenticated,)
    filterset_fields = ("badge_type", "frequency")
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

    @action(methods=["post"], detail=False, url_path="daily-sync")
    def daily_sync(self, request):
        target_date = timezone.localdate()
        assignments = services.assign_daily_missions_for_user(request.user, date=target_date)
        serializer = self.get_serializer(assignments, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)
