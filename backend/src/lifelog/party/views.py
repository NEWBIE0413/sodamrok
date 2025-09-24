from __future__ import annotations

import secrets

from django.db.models import Q
from rest_framework import permissions, viewsets

from .models import PartyMember, PartyPosition, PartySession
from .serializers import (
    PartyMemberSerializer,
    PartyPositionSerializer,
    PartySessionCreateSerializer,
    PartySessionSerializer,
)


class PartySessionViewSet(viewsets.ModelViewSet):
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        user = self.request.user
        qs = PartySession.objects.prefetch_related("members__user").select_related("trip", "host_user")
        if user.is_staff:
            return qs
        return qs.filter(Q(host_user=user) | Q(members__user=user)).distinct()

    def get_serializer_class(self):
        if self.action == "create":
            return PartySessionCreateSerializer
        return PartySessionSerializer

    def perform_create(self, serializer):
        serializer.save(host_user=self.request.user, sharable_token=secrets.token_urlsafe(16))


class PartyPositionViewSet(viewsets.ModelViewSet):
    serializer_class = PartyPositionSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        user = self.request.user
        qs = PartyPosition.objects.select_related("session", "user")
        if user.is_staff:
            return qs
        return qs.filter(user=user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class PartyMemberViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = PartyMemberSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        user = self.request.user
        qs = PartyMember.objects.select_related("session", "user")
        if user.is_staff:
            return qs
        return qs.filter(user=user)
