import 'dart:ui';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'package:sodamrok/app/widgets/top_bar.dart';
import '../features/home/presentation/home_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with TickerProviderStateMixin {
  int _selectedDrawerTab = 0; // 서랍 내 탭 선택 상태 (0: 피드, 1: 글쓰기, 2: 프로필)
  final ScrollController _scrollController = ScrollController();
  bool _showBottomBar = false;
  bool _isFeedMode = true; // 피드/트립 토글 상태
  final bool _showToggleFab = true; // 토글 FAB 표시 여부
  bool _isFeedFullyExpanded = false; // 피드가 완전히 열렸는지 상태

  // 검색 관련 상태
  bool _isSearchActive = false;
  late final AnimationController _searchAnimationController;
  late final Animation<double> _searchSlideAnimation;
  late final Animation<double> _searchBlurAnimation;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // 검색 애니메이션 초기화
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _searchSlideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeOutQuart,
    ));

    _searchBlurAnimation = Tween<double>(
      begin: 0.0,
      end: 8.0,
    ).animate(CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeOut,
    ));

  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchAnimationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldShowBottomBar = _scrollController.offset <= 0;
    if (shouldShowBottomBar != _showBottomBar) {
      setState(() {
        _showBottomBar = shouldShowBottomBar;
      });
    }
  }

  void _onFeedExpansionChanged(bool isFullyExpanded) {
    if (_isFeedFullyExpanded != isFullyExpanded) {
      setState(() {
        _isFeedFullyExpanded = isFullyExpanded;
      });
    }
  }

  void _showSearchScreen() {
    setState(() {
      _isSearchActive = true;
    });
    _searchAnimationController.forward();
    // 약간의 지연 후 포커스
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _hideSearchScreen() {
    _searchFocusNode.unfocus();
    _searchAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isSearchActive = false;
          _searchController.clear();
        });
      }
    });
  }

  void _showNotificationsPlaceholder() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('알림 기능을 준비 중이에요.')),
    );
  }

  void _toggleMode() {
    setState(() {
      _isFeedMode = !_isFeedMode;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: TopBar.home(
        onSearchTap: _showSearchScreen,
        onNotificationsTap: _showNotificationsPlaceholder,
      ),
      body: Stack(
        children: [
          // 메인 콘텐츠 - 항상 홈 화면만 표시, 서랍 콘텐츠만 변경
          Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverFillRemaining(
                    child: HomeScreen(
                      isFeedMode: _isFeedMode,
                      onFeedExpansionChanged: _onFeedExpansionChanged,
                      selectedTab: _selectedDrawerTab,
                      toggleButton: _showToggleFab
                          ? _CustomToggleButton(
                              isFeedMode: _isFeedMode,
                              onToggle: _toggleMode,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),

              // 하단바 표시 로직
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 200),
                  offset: (_isFeedMode && _isFeedFullyExpanded)
                      ? Offset.zero
                      : const Offset(0, 1), // 화면 아래로 숨김
                  child: IgnorePointer(
                    ignoring: !(_isFeedMode && _isFeedFullyExpanded),
                    child: _OverlayBottomBar(
                      selectedIndex: _selectedDrawerTab,
                      onTap: (index) {
                        setState(() {
                          _selectedDrawerTab = index;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 검색 오버레이
          if (_isSearchActive)
            _SearchOverlay(
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              slideAnimation: _searchSlideAnimation,
              blurAnimation: _searchBlurAnimation,
              onClose: _hideSearchScreen,
            ),
        ],
      ),
      floatingActionButton: null, // Scaffold의 기본 FAB 사용하지 않음
    );
  }
}

// 오버레이 하단바 위젯
class _OverlayBottomBar extends StatelessWidget {
  const _OverlayBottomBar({
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: Color(0xFFE4E0D8), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CustomNavItem(
              iconPath: selectedIndex == 0
                  ? 'assets/icons/explore_toggle.png'
                  : 'assets/icons/explore.png',
              isSelected: selectedIndex == 0,
              onTap: () => onTap(0),
            ),
            _CustomNavItem(
              iconPath: selectedIndex == 1
                  ? 'assets/icons/write_toggle.png'
                  : 'assets/icons/write.png',
              isSelected: selectedIndex == 1,
              onTap: () => onTap(1),
            ),
            _CustomNavItem(
              iconPath: selectedIndex == 2
                  ? 'assets/icons/profile_toggle.png'
                  : 'assets/icons/profile.png',
              isSelected: selectedIndex == 2,
              onTap: () => onTap(2),
            ),
          ],
        ),
      ),
    );
  }
}

// 커스텀 네비게이션 아이템
class _CustomNavItem extends StatelessWidget {
  const _CustomNavItem({
    required this.iconPath,
    required this.isSelected,
    required this.onTap,
  });

  final String iconPath;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: AnimatedScale(
          scale: isSelected ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Image.asset(
            iconPath,
            width: 43,
            height: 43,
          ),
        ),
      ),
    );
  }
}

// 커스텀 토글 버튼
class _CustomToggleButton extends StatelessWidget {
  const _CustomToggleButton({
    required this.isFeedMode,
    required this.onToggle,
  });

  final bool isFeedMode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isFeedMode ? Colors.white : null,
          gradient: isFeedMode
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isFeedMode
              ? ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Icon(
                    Icons.map_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                )
              : Icon(
                  Icons.home_rounded,
                  color: Colors.white,
                  size: 32,
                ),
        ),
      ),
    );
  }
}



// 검색 오버레이 위젯
class _SearchOverlay extends StatelessWidget {
  const _SearchOverlay({
    required this.searchController,
    required this.searchFocusNode,
    required this.slideAnimation,
    required this.blurAnimation,
    required this.onClose,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final Animation<double> slideAnimation;
  final Animation<double> blurAnimation;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: slideAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // 블러 배경
            AnimatedBuilder(
              animation: blurAnimation,
              builder: (context, child) {
                return BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: blurAnimation.value,
                    sigmaY: blurAnimation.value,
                  ),
                  child: GestureDetector(
                    onTap: onClose,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.3 * (blurAnimation.value / 8.0)),
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                );
              },
            ),

            // 검색 패널
            Positioned(
              top: slideAnimation.value * MediaQuery.of(context).size.height,
              left: 0,
              right: 0,
              child: Material(
                elevation: 8,
                color: AppColors.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 검색바
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0xFF3A7D74),
                                    width: 2,
                                  ),
                                ),
                                child: TextField(
                                  controller: searchController,
                                  focusNode: searchFocusNode,
                                  decoration: const InputDecoration(
                                    hintText: '장소나 태그를 검색해 보세요.',
                                    hintStyle: TextStyle(color: AppColors.textSecondary),
                                    prefixIcon: Icon(
                                      Icons.search_rounded,
                                      color: Color(0xFF3A7D74),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  onSubmitted: (value) {
                                    // TODO: 검색 실행
                                    if (value.trim().isNotEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('검색: "$value"')),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: onClose,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey.shade200,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // 최근 검색어 또는 추천 검색어
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '추천 검색어',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMain,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  '카페',
                                  '맛집',
                                  '공원',
                                  '박물관',
                                  '쇼핑몰',
                                  '영화관',
                                ].map((tag) => _SearchTag(
                                  text: tag,
                                  onTap: () {
                                    searchController.text = tag;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('검색: "$tag"')),
                                    );
                                  },
                                )).toList(),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// 검색 태그 위젯
class _SearchTag extends StatelessWidget {
  const _SearchTag({
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF3A7D74).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF3A7D74).withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF3A7D74),
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}



