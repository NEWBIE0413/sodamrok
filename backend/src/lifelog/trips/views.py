from __future__ import annotations

import logging

from django.shortcuts import get_object_or_404
from rest_framework import mixins, permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import Trip, TripTemplate, TripTemplateGenerationJob
from .serializers import (
    TripFromTemplateRequestSerializer,
    TripRecommendationRequestSerializer,
    TripSerializer,
    TripTemplateSerializer,
    TripTemplateWriteSerializer,
    TripWriteSerializer,
    TripTemplateGenerationJobCreateSerializer,
    TripTemplateGenerationJobSerializer,
)
from .tasks import generate_trip_recommendations, request_ai_template
from .services import create_trip_from_template

logger = logging.getLogger(__name__)


class IsStaffOrReadOnly(permissions.BasePermission):
    def has_permission(self, request, view):
        if request.method in permissions.SAFE_METHODS:
            return True
        return bool(request.user and request.user.is_staff)


class TripTemplateViewSet(viewsets.ModelViewSet):
    queryset = TripTemplate.objects.prefetch_related("nodes__place", "tags").order_by("-created_at")
    permission_classes = (IsStaffOrReadOnly,)

    def get_serializer_class(self):
        if self.action in {"create", "update", "partial_update"}:
            return TripTemplateWriteSerializer
        return TripTemplateSerializer

    def get_queryset(self):
        qs = super().get_queryset()
        if self.request.user.is_staff:
            return qs
        return qs.filter(is_published=True)

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)


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

    @action(methods=["post"], detail=False, url_path="recommendations")
    def recommendations(self, request):
        request_serializer = TripRecommendationRequestSerializer(data=request.data)
        request_serializer.is_valid(raise_exception=True)
        result = generate_trip_recommendations.apply(args=(str(request.user.id), request_serializer.validated_data))
        payload = result.get() if hasattr(result, "get") else result
        if payload.get("status") == "error":
            return Response(payload, status=status.HTTP_400_BAD_REQUEST)
        trip_id = payload.get("trip_id")
        trip = Trip.objects.prefetch_related("nodes__place").get(id=trip_id)
        serializer = TripSerializer(trip, context=self.get_serializer_context())
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(methods=["post"], detail=False, url_path="from-template")
    def from_template(self, request):
        serializer = TripFromTemplateRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        template = get_object_or_404(
            TripTemplate.objects.prefetch_related("nodes__place"),
            id=serializer.validated_data["template_id"],
        )
        if not template.is_published and not request.user.is_staff:
            return Response({"detail": "Template is not available."}, status=status.HTTP_403_FORBIDDEN)
        trip = create_trip_from_template(
            template=template,
            owner=request.user,
            title_override=serializer.validated_data.get("title"),
        )
        data = TripSerializer(trip, context=self.get_serializer_context()).data
        return Response(data, status=status.HTTP_201_CREATED)












class TripTemplateGenerationJobViewSet(
    mixins.CreateModelMixin,
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    viewsets.GenericViewSet,
):
    queryset = TripTemplateGenerationJob.objects.all().order_by("-created_at")
    permission_classes = (permissions.IsAuthenticated,)
    lookup_field = "id"

    def get_queryset(self):
        qs = super().get_queryset()
        user = self.request.user
        if user.is_staff:
            return qs
        return qs.filter(requested_by=user)

    def get_serializer_class(self):
        if self.action == "create":
            return TripTemplateGenerationJobCreateSerializer
        return TripTemplateGenerationJobSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        job = serializer.save()
        try:
            request_ai_template.delay(str(job.id))
        except Exception as exc:  # pragma: no cover - guard against celery misconfig
            logger.exception("Failed to enqueue AI template job %s", job.id)
            job.mark_failed("dispatch_error", str(exc))
            return Response(
                {
                    "detail": "AI 템플릿 생성 작업을 대기열에 추가하지 못했습니다.",
                    "job_id": str(job.id),
                },
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        output = TripTemplateGenerationJobSerializer(job, context=self.get_serializer_context())
        headers = self.get_success_headers(output.data)
        return Response(output.data, status=status.HTTP_201_CREATED, headers=headers)

