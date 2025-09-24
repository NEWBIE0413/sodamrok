from __future__ import annotations

from rest_framework import permissions, viewsets

from .models import Post
from .serializers import PostSerializer, PostWriteSerializer


class IsAuthorOrReadOnly(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        return obj.author_id == getattr(request.user, "id", None)


class PostViewSet(viewsets.ModelViewSet):
    queryset = Post.objects.select_related("author", "place").prefetch_related("tags")
    permission_classes = (permissions.IsAuthenticated, IsAuthorOrReadOnly)
    filterset_fields = ("post_type", "visibility", "status", "tags__name")
    search_fields = ("title", "body", "tags__name")
    ordering_fields = ("created_at", "published_at")

    def get_serializer_class(self):
        if self.action in {"create", "update", "partial_update"}:
            return PostWriteSerializer
        return PostSerializer

    def perform_create(self, serializer):
        serializer.save(author=self.request.user)

    def get_queryset(self):
        qs = super().get_queryset()
        user = self.request.user
        if not user.is_authenticated:
            return qs.none()
        if user.is_staff:
            return qs
        return qs.filter(author=user)
