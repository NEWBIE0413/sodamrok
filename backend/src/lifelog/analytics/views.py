from __future__ import annotations

from rest_framework import permissions, viewsets

from .models import DailyProductMetric
from .serializers import DailyProductMetricSerializer


class DailyProductMetricViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = DailyProductMetricSerializer
    permission_classes = (permissions.IsAdminUser,)
    queryset = DailyProductMetric.objects.all()
    filterset_fields = ("metric", "date")
    search_fields = ("metric",)
    ordering = ("-date",)

