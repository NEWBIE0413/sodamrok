from __future__ import annotations

from django.db.models import Count, Q
from rest_framework import permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import Post, PostComment, PostLike
from .serializers import (
    PostCommentCreateSerializer,
    PostCommentSerializer,
    PostSerializer,
    PostWriteSerializer,
)


class IsAuthorOrReadOnly(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        return obj.author_id == getattr(request.user, "id", None)


class PostViewSet(viewsets.ModelViewSet):
    queryset = (
        Post.objects.select_related("author", "place")
        .prefetch_related("tags", "likes__user", "comments__author")
        .annotate(
            like_count=Count("likes", distinct=True),
            comment_count=Count("comments", distinct=True),
        )
    )
    permission_classes = (permissions.IsAuthenticatedOrReadOnly, IsAuthorOrReadOnly)
    filterset_fields = ("post_type", "visibility", "status", "tags__name")
    search_fields = ("title", "body", "tags__name")
    ordering_fields = ("created_at", "published_at")

    def get_serializer_class(self):
        if self.action in {"create", "update", "partial_update"}:
            return PostWriteSerializer
        return PostSerializer

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        ctx["request"] = self.request
        return ctx

    def perform_create(self, serializer):
        serializer.save(author=self.request.user)

    def get_queryset(self):
        qs = super().get_queryset()
        user = self.request.user
        if not user.is_authenticated:
            return qs.filter(
                visibility=Post.Visibility.PUBLIC,
                status=Post.Status.PUBLISHED,
            )
        if user.is_staff:
            return qs
        return qs.filter(Q(author=user) | Q(visibility=Post.Visibility.PUBLIC))

    @action(detail=True, methods=["post", "delete"], permission_classes=[permissions.IsAuthenticated])
    def like(self, request, pk=None):
        post = self.get_object()
        user = request.user

        if request.method.lower() == "post":
            PostLike.objects.get_or_create(post=post, user=user)
            liked = True
        else:
            PostLike.objects.filter(post=post, user=user).delete()
            liked = False

        like_count = PostLike.objects.filter(post=post).count()
        comment_count = PostComment.objects.filter(post=post).count()
        return Response(
            {
                "post_id": str(post.id),
                "liked": liked,
                "like_count": like_count,
                "comment_count": comment_count,
            },
            status=status.HTTP_200_OK,
        )

    @action(detail=True, methods=["get", "post"], url_path="comments", permission_classes=[permissions.AllowAny])
    def comments(self, request, pk=None):
        post = self.get_object()
        context = self.get_serializer_context()

        if request.method.lower() == "get":
            comments = post.comments.select_related("author").order_by("-created_at")
            serializer = PostCommentSerializer(comments, many=True, context=context)
            return Response(serializer.data)

        if not request.user.is_authenticated:
            return Response({"detail": "로그인이 필요합니다."}, status=status.HTTP_401_UNAUTHORIZED)

        serializer = PostCommentCreateSerializer(data=request.data, context=context)
        serializer.is_valid(raise_exception=True)

        comment = PostComment.objects.create(
            post=post,
            author=request.user,
            content=serializer.validated_data["content"],
        )
        output = PostCommentSerializer(comment, context=context)
        comment_count = PostComment.objects.filter(post=post).count()
        return Response(
            {"comment": output.data, "comment_count": comment_count},
            status=status.HTTP_201_CREATED,
        )

