import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/dependencies/app_dependencies.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/spacing.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/login_screen.dart';
import '../data/services/post_interaction_service.dart';
import '../domain/exceptions/home_feed_exception.dart';
import '../domain/repositories/home_feed_repository.dart';
import '../domain/models/home_feed_post.dart';
import 'widgets/kakao_map_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeFeedData> _feedFuture;
  List<HomeFeedPost> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    _feedFuture = AppDependencies.homeFeedRepository.fetchFeed();
    final feedData = await _feedFuture;
    setState(() {
      _posts = feedData.posts;
    });
  }

  void _handlePostMarkerTapped(String postId, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('게시글 선택: $title')),
    );
  }

  void _handleMapTapped(double lat, double lng) {
    debugPrint('지도 클릭: $lat, $lng');
  }

  @override
  Widget build(BuildContext context) {
    const topBarHeight = 64.0;
    const locationLabel = '수원 팔달구';
    final mediaQuery = MediaQuery.of(context);
    final badgeTop = mediaQuery.padding.top + 16;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('추천 받기'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [
          KakaoMapWidget(
            posts: _posts,
            onPostMarkerTapped: _handlePostMarkerTapped,
            onMapTapped: _handleMapTapped,
          ),
          Positioned(
            top: badgeTop,
            left: 16,
            child: const _LocationBadge(label: locationLabel),
          ),
          Positioned.fill(child: _FeedSheet(feedFuture: _feedFuture)),
        ],
      ),
    );
  }
}


class _LocationBadge extends StatelessWidget {
  const _LocationBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 6,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE0D8CF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
            Gaps.xs,
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMain,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedSheet extends StatefulWidget {
  const _FeedSheet({required this.feedFuture});

  final Future<HomeFeedData> feedFuture;
  static const double _collapsedHeight = 136;

  @override
  State<_FeedSheet> createState() => _FeedSheetState();
}

enum _PostAction { like, comment }

class _FeedSheetState extends State<_FeedSheet> {
  late Future<HomeFeedData> _feedFuture;
  late final AuthController _authController;
  late final PostInteractionService _interactionService;
  late AuthStatus _lastStatus;
  bool _isPerformingAction = false;

  @override
  void initState() {
    super.initState();
    _authController = AppDependencies.authController;
    _interactionService = AppDependencies.postInteractionService;
    _lastStatus = _authController.status;
    _authController.addListener(_handleAuthChange);
    _feedFuture = widget.feedFuture;
  }

  @override
  void dispose() {
    _authController.removeListener(_handleAuthChange);
    super.dispose();
  }
  Future<HomeFeedData> _fetchFeed() {
    return AppDependencies.homeFeedRepository.fetchFeed();
  }

  Future<void> _reload() {
    final future = _fetchFeed();
    setState(() {
      _feedFuture = future;
    });
    return future;
  }

  Future<void> _handlePostAction(BuildContext context, HomeFeedPost post, _PostAction action) async {
    if (_isPerformingAction) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    if (!_authController.isAuthenticated) {
      final result = await showLoginModal(context, _authController);
      if (!context.mounted || result != true || !_authController.isAuthenticated) {
        return;
      }
    }

    String? pendingContent;
    if (action == _PostAction.comment) {
      pendingContent = await _promptForContent(
        context,
        title: '댓글 남기기',
        actionLabel: '댓글 달기',
        hintText: '댓글을 입력해 주세요.',
      );
      if (pendingContent == null || pendingContent.isEmpty) {
        return;
      }
    }

    setState(() {
      _isPerformingAction = true;
    });

    try {
      switch (action) {
        case _PostAction.like:
          final result = await _interactionService.toggleLike(postId: post.id, isLiked: post.isLiked);
          messenger.showSnackBar(
            SnackBar(content: Text(result.liked ? '좋아요를 눌렀어요.' : '좋아요를 취소했어요.')),
          );
          break;
        case _PostAction.comment:
          await _interactionService.createComment(postId: post.id, content: pendingContent!);
          messenger.showSnackBar(const SnackBar(content: Text('댓글을 남겼어요.')));
          break;
      }

      await _reload();
    } on DioException catch (error) {
      final detail = _extractErrorMessage(error.response?.data);
      messenger.showSnackBar(
        SnackBar(content: Text(detail ?? '요청을 처리하지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('요청을 처리하지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPerformingAction = false;
        });
      }
    }
  }


  String? _extractErrorMessage(dynamic data) {
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
      for (final value in data.values) {
        if (value is List && value.isNotEmpty) {
          final entry = value.first;
          if (entry is String && entry.isNotEmpty) {
            return entry;
          }
        } else if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    } else if (data is String && data.isNotEmpty) {
      return data;
    }
    return null;
  }

  Future<String?> _promptForContent(
    BuildContext context, {
    required String title,
    required String actionLabel,
    String? hintText,
  }) async {
    final controller = TextEditingController();
    final isValid = ValueNotifier<bool>(false);

    controller.addListener(() {
      isValid.value = controller.text.trim().isNotEmpty;
    });

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) {
        final bottomInset = MediaQuery.of(modalContext).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
                Gaps.md,
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: hintText,
                    border: const OutlineInputBorder(),
                  ),
                ),
                Gaps.md,
                ValueListenableBuilder<bool>(
                  valueListenable: isValid,
                  builder: (context, enabled, _) {
                    return FilledButton(
                      onPressed: enabled
                          ? () => Navigator.of(modalContext).pop(controller.text.trim())
                          : null,
                      child: Text(actionLabel),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();
    isValid.dispose();

    if (result == null) {
      return null;
    }
    final trimmed = result.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _handleAuthChange() {
    final status = _authController.status;
    if (!mounted) {
      return;
    }

    if (_lastStatus != status) {
      _reload();
      _lastStatus = status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveHeight = math.max(constraints.maxHeight - bottomInset, 1.0);
        final collapsedRatio = _FeedSheet._collapsedHeight / effectiveHeight;
        final minChildSize = collapsedRatio.clamp(0.14, 0.28).toDouble();

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: DraggableScrollableSheet(
            initialChildSize: minChildSize,
            minChildSize: minChildSize,
            maxChildSize: 1.0,
            snap: true,
            snapSizes: <double>[minChildSize, 1.0],
            builder: (context, controller) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Color(0xFFE0D8CF), width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                      child: Container(
                        width: 40,
                        height: 4,
                        color: const Color(0xFFD8D2C8),
                      ),
                    ),
                    Expanded(
                      child: FutureBuilder<HomeFeedData>(
                        future: _feedFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState != ConnectionState.done) {
                            return const _FeedLoading();
                          }

                          if (snapshot.hasError) {
                            return _FeedError(
                              message: _resolveErrorMessage(snapshot.error),
                              onRetry: _reload,
                            );
                          }

                          final posts = snapshot.data?.posts ?? const <HomeFeedPost>[];

                          if (posts.isEmpty) {
                            return const _FeedEmpty();
                          }

                          return RefreshIndicator(
                            onRefresh: _reload,
                            child: ListView.separated(
                              controller: controller,
                              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                              padding: EdgeInsets.fromLTRB(
                                Insets.md,
                                Insets.sm,
                                Insets.md,
                                Insets.lg + bottomInset,
                              ),
                              itemBuilder: (context, index) {
                                final post = posts[index];
                                return _FeedPostCard(
                                  post: post,
                                  isBusy: _isPerformingAction,
                                  onLike: () => _handlePostAction(context, post, _PostAction.like),
                                  onComment: () => _handlePostAction(context, post, _PostAction.comment),
                                );
                              },
                              separatorBuilder: (_, __) => const Divider(
                                height: Insets.lg * 2,
                                color: Color(0xFFE0D8CF),
                              ),
                              itemCount: posts.length,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _resolveErrorMessage(Object? error) {
    if (error is HomeFeedException) {
      return error.message;
    }
    return '피드를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.';
  }
}

class _FeedPostCard extends StatelessWidget {
  const _FeedPostCard({
    required this.post,
    required this.isBusy,
    required this.onLike,
    required this.onComment,
  });

  final HomeFeedPost post;
  final bool isBusy;
  final VoidCallback onLike;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                post.authorInitial,
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
            Gaps.sm,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.authorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                  ),
                ),
                Text(
                  post.timeAgoLabel,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              splashRadius: 20,
              icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
              onPressed: () {},
            ),
          ],
        ),
        Gaps.sm,
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFFECE7DE),
            border: Border.all(color: const Color(0xFFD6CDC2)),
          ),
          alignment: Alignment.center,
          child: Text(
            post.mediaLabel,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Gaps.sm,
        Text(
          post.caption,
          style: const TextStyle(color: AppColors.textMain),
        ),
        if (post.tags.isNotEmpty) ...[
          Gaps.xs,
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.xs,
            children: post.tags
                .map((tag) => Text(
                      '#$tag',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ))
                .toList(),
          ),
        ],
        Gaps.sm,
        Row(
          children: [
            IconButton(
              icon: Icon(
                post.isLiked ? Icons.favorite : Icons.favorite_border_outlined,
                color: post.isLiked ? AppColors.primary : AppColors.textSecondary,
              ),
              tooltip: '좋아요 남기기',
              onPressed: isBusy ? null : onLike,
            ),
            if (post.likeCount > 0) ...[
              const SizedBox(width: 4),
              Text(
                '${post.likeCount}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            Gaps.sm,
            IconButton(
              icon: const Icon(Icons.mode_comment_outlined, color: AppColors.textSecondary),
              tooltip: '댓글 남기기',
              onPressed: isBusy ? null : onComment,
            ),
            if (post.commentCount > 0) ...[
              const SizedBox(width: 4),
              Text(
                '${post.commentCount}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _FeedLoading extends StatelessWidget {
  const _FeedLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          Gaps.sm,
          TextButton(
            onPressed: () => onRetry(),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '아직 피드가 비어 있어요. 첫 기록을 남겨볼까요?',
        style: TextStyle(color: AppColors.textSecondary),
        textAlign: TextAlign.center,
      ),
    );
  }
}











