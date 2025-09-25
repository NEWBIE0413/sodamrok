from __future__ import annotations

from rest_framework import permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import Trip
from .serializers import TripRecommendationRequestSerializer, TripSerializer, TripWriteSerializer
from .tasks import generate_trip_recommendations


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

    @action(methods=['post'], detail=False, url_path='recommendations')
    def recommendations(self, request):
        request_serializer = TripRecommendationRequestSerializer(data=request.data)
        request_serializer.is_valid(raise_exception=True)
        result = generate_trip_recommendations.apply(args=(str(request.user.id), request_serializer.validated_data))
        payload = result.get() if hasattr(result, 'get') else result
        if payload.get('status') == 'error':
            return Response(payload, status=status.HTTP_400_BAD_REQUEST)
        trip_id = payload.get('trip_id')
        trip = Trip.objects.prefetch_related('nodes__place').get(id=trip_id)
        serializer = TripSerializer(trip, context=self.get_serializer_context())
        return Response(serializer.data, status=status.HTTP_201_CREATED)
