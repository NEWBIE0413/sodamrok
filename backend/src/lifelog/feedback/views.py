from __future__ import annotations

from rest_framework import permissions, viewsets

from .models import Feedback
from .serializers import FeedbackCreateSerializer, FeedbackSerializer


class FeedbackViewSet(viewsets.ModelViewSet):
    permission_classes = (permissions.IsAuthenticated,)
    filterset_fields = ("rating", "trip")
    ordering = ("-created_at",)

    def get_queryset(self):
        user = self.request.user
        qs = Feedback.objects.select_related("trip", "trip_node", "user")
        if user.is_staff:
            return qs
        return qs.filter(user=user)

    def get_serializer_class(self):
        if self.action == "create":
            return FeedbackCreateSerializer
        return FeedbackSerializer

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

