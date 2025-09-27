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
  const HomeScreen({
    super.key,
    this.isFeedMode = true,
    required this.toggleButton,
    this.onFeedExpansionChanged,
    this.customContent,
    this.selectedTab = 0,
  });

  final bool isFeedMode;
  final Widget toggleButton;
  final Function(bool)? onFeedExpansionChanged;
  final Widget? customContent;
  final int selectedTab;

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
          // 토글 버튼을 피드/트립 시트보다 뒤에 배치
          Positioned(
            right: 16,
            bottom: 156, // 닫힌 피드 기준 약간 위쪽
            child: widget.toggleButton,
          ),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 1.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOut,
                  )),
                  child: child,
                );
              },
              child: widget.isFeedMode
                  ? _ContentSheet(
                      key: const ValueKey('feed'),
                      selectedTab: widget.selectedTab,
                      feedFuture: _feedFuture,
                      onExpansionChanged: widget.onFeedExpansionChanged ?? (_) {},
                    )
                  : const _TripSheet(
                      key: ValueKey('trip'),
                    ),
            ),
          ),
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

// 간단한 콘텐츠 시트 - 하단바 탭에 따라 콘텐츠 변경
class _ContentSheet extends StatefulWidget {
  const _ContentSheet({
    super.key,
    required this.selectedTab,
    required this.feedFuture,
    required this.onExpansionChanged,
  });

  final int selectedTab; // 하단바에서 선택된 탭 (0: 피드, 1: 글쓰기, 2: 프로필)
  final Future<HomeFeedData> feedFuture;
  final Function(bool) onExpansionChanged;
  static const double _collapsedHeight = 136;

  @override
  State<_ContentSheet> createState() => _ContentSheetState();
}

enum _PostAction { like, comment }

class _ContentSheetState extends State<_ContentSheet> {
  late Future<HomeFeedData> _feedFuture;
  late final AuthController _authController;
  late final PostInteractionService _interactionService;
  late AuthStatus _lastStatus;
  bool _isPerformingAction = false;
  bool _lastExpansionState = false;

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
        final collapsedRatio = _ContentSheet._collapsedHeight / effectiveHeight;
        final minChildSize = collapsedRatio.clamp(0.14, 0.28).toDouble();

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              final isFullyExpanded = notification.extent >= 0.95;

              if (_lastExpansionState != isFullyExpanded) {
                _lastExpansionState = isFullyExpanded;

                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted) {
                    widget.onExpansionChanged.call(isFullyExpanded);
                  }
                });
              }
              return false;
            },
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
                    // 모든 탭을 백그라운드에서 렌더링하되 비활성 탭은 터치 무시
                    Expanded(
                      child: IndexedStack(
                        index: widget.selectedTab,
                        children: [
                          IgnorePointer(
                            ignoring: widget.selectedTab != 0,
                            child: _FeedTabContent(
                              feedFuture: _feedFuture,
                              controller: widget.selectedTab == 0 ? controller : null,
                              isPerformingAction: _isPerformingAction,
                              onReload: _reload,
                              onPostAction: _handlePostAction,
                              onShare: _handleSharePost,
                              onProfileTap: _handleProfileTap,
                            ),
                          ),
                          IgnorePointer(
                            ignoring: widget.selectedTab != 1,
                            child: _WriteTabContent(controller: widget.selectedTab == 1 ? controller : null),
                          ),
                          IgnorePointer(
                            ignoring: widget.selectedTab != 2,
                            child: _ProfileTabContent(controller: widget.selectedTab == 2 ? controller : null),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
            ),
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

          // Caption (내용을 사진 위로 이동)
          if (post.caption.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              child: Text(
                post.caption,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            Gaps.sm,
          ],

          // Media/Content Section은 그대로 유지

          Gaps.sm,

          // Action buttons row with counts
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Row(
              children: [
                _ActionButtonWithCount(
                  iconPath: post.isLiked ? 'assets/icons/heart_toggle.png' : 'assets/icons/heart.png',
                  count: post.likeCount,
                  onPressed: isBusy ? null : onLike,
                ),
                Gaps.md,
                _ActionButtonWithCount(
                  iconPath: 'assets/icons/comment.png',
                  count: post.commentCount,
                  onPressed: isBusy ? null : onComment,
                ),
                Gaps.md,
                _ActionButtonWithCount(
                  iconPath: 'assets/icons/share.png',
                  count: 0, // 공유는 카운트 없음
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


          Gaps.md,
        ],
      ),
    );
  }
}

class _ActionButtonWithCount extends StatelessWidget {
  const _ActionButtonWithCount({
    super.key,
    required this.iconPath,
    required this.count,
    required this.onPressed,
  });

  final String iconPath;
  final int count;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            iconPath,
            width: 28,
            height: 28,
            color: onPressed == null ? Colors.grey : null,
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textMain,
              ),
            ),
          ],
        ],
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

// 트립 시트 - 피드 시트와 동일한 구조
// 피드 탭 콘텐츠 - 스크롤 위치 유지
class _FeedTabContent extends StatefulWidget {
  const _FeedTabContent({
    super.key,
    required this.feedFuture,
    this.controller,
    required this.isPerformingAction,
    required this.onReload,
    required this.onPostAction,
    required this.onShare,
    required this.onProfileTap,
  });

  final Future<HomeFeedData> feedFuture;
  final ScrollController? controller;
  final bool isPerformingAction;
  final Future<void> Function() onReload;
  final Future<void> Function(BuildContext, HomeFeedPost, _PostAction) onPostAction;
  final void Function(BuildContext, HomeFeedPost) onShare;
  final void Function(BuildContext, String) onProfileTap;

  @override
  State<_FeedTabContent> createState() => _FeedTabContentState();
}

class _FeedTabContentState extends State<_FeedTabContent> with AutomaticKeepAliveClientMixin {
  ScrollController? _internalController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _internalController = ScrollController();
  }

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수

    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom;

    // 외부 controller가 있으면 우선 사용, 없으면 내부 controller 사용
    final scrollController = widget.controller ?? _internalController;

    return FutureBuilder<HomeFeedData>(
      future: widget.feedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _FeedLoading();
        }

        if (snapshot.hasError) {
          return _FeedError(
            message: _resolveErrorMessage(snapshot.error),
            onRetry: widget.onReload,
          );
        }

        final posts = snapshot.data?.posts ?? const <HomeFeedPost>[];

        if (posts.isEmpty) {
          return const _FeedEmpty();
        }

        return RefreshIndicator(
          onRefresh: widget.onReload,
          child: ListView.builder(
            controller: scrollController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: EdgeInsets.only(
              top: Insets.xs,
              bottom: Insets.xl + bottomInset,
            ),
            itemBuilder: (context, index) {
              final post = posts[index];
              return _ModernFeedPostCard(
                post: post,
                isBusy: widget.isPerformingAction,
                onLike: () => widget.onPostAction(context, post, _PostAction.like),
                onComment: () => widget.onPostAction(context, post, _PostAction.comment),
                onShare: () => widget.onShare(context, post),
                onProfileTap: () => widget.onProfileTap(context, post.authorName),
              );
            },
            itemCount: posts.length,
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

// 글쓰기 탭 콘텐츠
class _WriteTabContent extends StatelessWidget {
  const _WriteTabContent({super.key, this.controller});

  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '새 게시글 작성',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '소중한 순간을 기록해보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),

          // 사진 첨부 영역
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 32,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(height: 8),
                Text(
                  '사진 추가',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            decoration: InputDecoration(
              hintText: '제목을 입력하세요',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            maxLines: 5,
            decoration: InputDecoration(
              hintText: '내용을 입력하세요',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),

          const SizedBox(height: 16),

          // 위치 태그 버튼
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  '위치 태그 추가',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '게시하기',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 프로필 탭 콘텐츠
class _ProfileTabContent extends StatelessWidget {
  const _ProfileTabContent({super.key, this.controller});

  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 상단 헤더 (프로필 + 아이콘들)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 우측 상단 아이콘들과 프로필 정보
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 프로필 정보 (좌측 정렬)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        // 프로필 이미지
                        Container(
                          width: 80,
                          height: 80,
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
                          child: const Center(
                            child: Text(
                              '사용자',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 이름
                        const Text(
                          '소담록 사용자',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 우측 상단 아이콘들
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('프로필 수정')),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined),
                        iconSize: 24,
                        color: AppColors.textSecondary,
                      ),
                      IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('설정')),
                          );
                        },
                        icon: const Icon(Icons.settings_outlined),
                        iconSize: 24,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        // 구분선
        Container(
          height: 1,
          color: Colors.grey.shade200,
        ),
        // 게시글 목록
        Expanded(
          child: SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '내 게시글',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 16),
                // 게시글 그리드 (임시 데이터)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: 9, // 임시 게시글 수
                  itemBuilder: (context, index) {
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F6F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE8E3DB)),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 32,
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TripSheet extends StatefulWidget {
  const _TripSheet({super.key});

  static const double _collapsedHeight = 136;

  @override
  State<_TripSheet> createState() => _TripSheetState();
}

class _TripSheetState extends State<_TripSheet> {
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveHeight = math.max(constraints.maxHeight - bottomInset, 1.0);
        final collapsedRatio = _TripSheet._collapsedHeight / effectiveHeight;
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
                      child: CustomScrollView(
                        controller: controller,
                        slivers: [
                          const SliverToBoxAdapter(child: SizedBox(height: 20)),

                          // 추천 트립 코스 섹션
                          SliverToBoxAdapter(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: Insets.lg),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE0D8CF)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        color: Color(0xFF3A7D74),
                                        size: 24,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        '추천 트립 코스',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textMain,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    '어디론가 떠나고 싶지 않으신가요?\n주변에서 핫한 스팟을 스마트하게 엮어 구성된 트립코스를 따라가보세요!',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('추천 코스 기능을 준비 중이에요'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3A7D74),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('코스 둘러보기'),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SliverToBoxAdapter(child: SizedBox(height: 20)),

                          // 나의 스팟 섹션
                          SliverToBoxAdapter(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: Insets.lg),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE0D8CF)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.bookmark_rounded,
                                        color: Color(0xFF3A7D74),
                                        size: 24,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        '나의 스팟',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textMain,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    '내가 찜한 스팟들을 모아보고, 원하는 곳들을 골라 나만의 트립코스를 만들어보세요',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('스팟 관리 기능을 준비 중이에요'),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          },
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Color(0xFF3A7D74)),
                                            foregroundColor: const Color(0xFF3A7D74),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text('내 스팟 관리'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('AI 트립코스 제작 기능을 준비 중이에요'),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF3A7D74),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text('코스 제작'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SliverToBoxAdapter(child: SizedBox(height: 100)), // FAB 공간 확보
                        ],
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
}











