import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart' as loc;

import '../../../core/dependencies/app_dependencies.dart';
import '../../../core/services/kakao_rest_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/spacing.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/modern_login_screen.dart';
import '../data/services/post_interaction_service.dart';
import '../domain/exceptions/home_feed_exception.dart';
import '../domain/repositories/home_feed_repository.dart';
import '../domain/models/home_feed_post.dart';
import 'widgets/hand_drawn_map_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeFeedData> _feedFuture;
  List<HomeFeedPost> _posts = [];
  String _currentAddress = '현재 위치';
  final loc.Location _location = loc.Location();

  @override
  void initState() {
    super.initState();
    _feedFuture = AppDependencies.homeFeedRepository.fetchFeed();
    _loadFeed();
    _getCurrentLocation();
  }

  Future<void> _loadFeed() async {
    try {
      final feedData = await _feedFuture;
      if (mounted) {
        setState(() {
          _posts = feedData.posts;
        });
      }
    } catch (e) {
      debugPrint('피드 로드 실패: $e');
      if (mounted) {
        setState(() {
          _posts = [];
        });
      }
    }
  }

  void _handlePostMarkerTapped(String postId, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('게시글 선택: $title')),
    );
  }

  void _handleMapTapped(double lat, double lng) {
    debugPrint('지도 클릭: $lat, $lng');
  }

  Future<void> _getCurrentLocation() async {
    try {
      // 위치 서비스 활성화 확인
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          debugPrint('위치 서비스가 비활성화되어 있습니다.');
          return;
        }
      }

      // 위치 권한 확인
      loc.PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) {
          debugPrint('위치 권한이 거부되었습니다.');
          return;
        }
      }

      // 현재 위치 가져오기
      final loc.LocationData locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        await _getAddressFromCoordinates(
          locationData.latitude!,
          locationData.longitude!,
        );
      }
    } catch (e) {
      debugPrint('현재 위치 가져오기 실패: $e');
    }
  }

  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final address = await KakaoRestApiService.getAddressFromCoordinates(lat, lng);
      if (mounted) {
        setState(() {
          _currentAddress = address;
        });
        debugPrint('현재 주소: $address');
      }
    } catch (e) {
      debugPrint('주소 변환 실패: $e');
      if (mounted) {
        setState(() {
          _currentAddress = '위치 정보 없음';
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
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
          HandDrawnMapWidget(
            posts: _posts,
            onPostMarkerTapped: _handlePostMarkerTapped,
            onMapTapped: _handleMapTapped,
            onMapReady: () => debugPrint('Hand-drawn Maps 준비 완료!'),
          ),
          Positioned(
            top: badgeTop,
            left: 16,
            child: _LocationBadge(label: _currentAddress),
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
      final result = await showModernLoginModal(context, _authController);
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

  void _handleSharePost(BuildContext context, HomeFeedPost post) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${post.authorName}님의 게시글을 공유했어요'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _handleProfileTap(BuildContext context, String authorName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$authorName님의 프로필'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
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
                            child: ListView.builder(
                              controller: controller,
                              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                              padding: EdgeInsets.only(
                                top: Insets.xs,
                                bottom: Insets.xl + bottomInset,
                              ),
                              itemBuilder: (context, index) {
                                final post = posts[index];
                                return _ModernFeedPostCard(
                                  post: post,
                                  isBusy: _isPerformingAction,
                                  onLike: () => _handlePostAction(context, post, _PostAction.like),
                                  onComment: () => _handlePostAction(context, post, _PostAction.comment),
                                  onShare: () => _handleSharePost(context, post),
                                  onProfileTap: () => _handleProfileTap(context, post.authorName),
                                );
                              },
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

class _ModernFeedPostCard extends StatelessWidget {
  const _ModernFeedPostCard({
    required this.post,
    required this.isBusy,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onProfileTap,
  });

  final HomeFeedPost post;
  final bool isBusy;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Insets.xs),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0F0F0), width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Profile + More button)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onProfileTap,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.accent,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            post.authorInitial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
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
                              fontSize: 14,
                            ),
                          ),
                          if (post.timeAgoLabel.isNotEmpty)
                            Text(
                              post.timeAgoLabel,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  splashRadius: 18,
                  icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary, size: 20),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // Media/Content Section
          Container(
            width: double.infinity,
            height: 280,
            margin: const EdgeInsets.symmetric(horizontal: Insets.md),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F6F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8E3DB)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Placeholder for image
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 48,
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                    Gaps.sm,
                    Text(
                      post.mediaLabel,
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                // Location tag (if available)
                if (post.tags.isNotEmpty)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, color: Colors.white, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            post.tags.first,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Gaps.sm,

          // Action buttons row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Row(
              children: [
                _ActionButton(
                  icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: post.isLiked ? Colors.red : AppColors.textSecondary,
                  onPressed: isBusy ? null : onLike,
                ),
                Gaps.sm,
                _ActionButton(
                  icon: Icons.mode_comment_outlined,
                  color: AppColors.textSecondary,
                  onPressed: isBusy ? null : onComment,
                ),
                Gaps.sm,
                _ActionButton(
                  icon: Icons.share_outlined,
                  color: AppColors.textSecondary,
                  onPressed: onShare,
                ),
                const Spacer(),
                if (post.tags.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#${post.tags.skip(1).first}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Like count
          if (post.likeCount > 0 || post.commentCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Gaps.xs,
                  Row(
                    children: [
                      if (post.likeCount > 0) ...[
                        Text(
                          '좋아요 ${post.likeCount}개',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMain,
                            fontSize: 13,
                          ),
                        ),
                        if (post.commentCount > 0) ...[
                          const Text(' · ', style: TextStyle(color: AppColors.textSecondary)),
                          Text(
                            '댓글 ${post.commentCount}개',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ] else if (post.commentCount > 0)
                        Text(
                          '댓글 ${post.commentCount}개',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

          // Caption
          if (post.caption.isNotEmpty) ...[
            Gaps.xs,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: '${post.authorName} ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: post.caption),
                  ],
                ),
              ),
            ),
          ],

          Gaps.md,
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          color: color,
          size: 24,
        ),
      ),
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











