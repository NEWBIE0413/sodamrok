import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../shared/utils/spacing.dart';
import 'package:sodamrok/app/widgets/top_bar.dart';
import '../features/home/presentation/home_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  final ScrollController _scrollController = ScrollController();
  bool _showBottomBar = false;
  bool _isFeedMode = true; // 피드/트립 토글 상태
  final bool _showToggleFab = true; // 토글 FAB 표시 여부
  late final List<Widget> _pages;
  late final List<PreferredSizeWidget> _topBars;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _pages = [
      HomeScreen(
        toggleButton: _showToggleFab
            ? _CustomToggleButton(
                isFeedMode: _isFeedMode,
                onToggle: _toggleMode,
              )
            : const SizedBox.shrink(),
      ), // 동적으로 전달할 예정
      const _TripScreen(),
      const _SearchPlaceholderPage(),
    ];

    _topBars = [
      TopBar.home(
        onSearchTap: _showSearchScreen,
        onNotificationsTap: _showNotificationsPlaceholder,
      ),
      TopBar.placeholder('트립'),
      TopBar.placeholder('검색'),
    ];
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldShowBottomBar = _currentIndex == 0 && _scrollController.offset <= 0;
    if (shouldShowBottomBar != _showBottomBar) {
      setState(() {
        _showBottomBar = shouldShowBottomBar;
      });
    }
  }

  void _showSearchScreen() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const _SearchScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
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
      appBar: _topBars[_currentIndex],
      body: _currentIndex == 0
          ? Stack(
              children: [
                CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverFillRemaining(
                      child: HomeScreen(
                        isFeedMode: _isFeedMode,
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
              ],
            )
          : _pages[_currentIndex],
      bottomNavigationBar: _showBottomBar ? Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: Color(0xFFE4E0D8), width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          height: 72,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
              _showBottomBar = false;
            });
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.map_rounded), label: '탐색'),
            NavigationDestination(icon: Icon(Icons.auto_awesome_rounded), label: '트립'),
            NavigationDestination(icon: Icon(Icons.search_rounded), label: '검색'),
          ],
        ),
      ) : null,
      floatingActionButton: null, // Scaffold의 기본 FAB 사용하지 않음
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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Container(
            key: ValueKey(isFeedMode),
            decoration: isFeedMode
                ? const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  )
                : null,
            child: Icon(
              isFeedMode ? Icons.explore_rounded : Icons.home_rounded,
              color: isFeedMode ? Colors.white : Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchPlaceholderPage extends StatelessWidget {
  const _SearchPlaceholderPage();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: Insets.lg),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_rounded,
              size: 64,
              color: Colors.grey,
            ),
            Gaps.md,
            Text(
              '검색 준비 중',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
            Gaps.sm,
            Text(
              '장소·태그 탐색 UI가 여기에 배치됩니다.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// 새로운 검색 화면
class _SearchScreen extends StatefulWidget {
  const _SearchScreen();

  @override
  State<_SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<_SearchScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _searchBarAnimation;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchBarAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    // 화면 진입시 애니메이션 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: AnimatedBuilder(
          animation: _searchBarAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _searchBarAnimation.value,
              alignment: Alignment.centerLeft,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '장소나 태그를 검색해보세요',
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.symmetric(horizontal: Insets.lg),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_rounded,
                size: 64,
                color: Colors.grey,
              ),
              Gaps.md,
              Text(
                '검색 기능 준비 중',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
              Gaps.sm,
              Text(
                '장소와 태그 탐색 기능이 곧 추가됩니다',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 새로운 트립 화면
class _TripScreen extends StatelessWidget {
  const _TripScreen();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // 추천 트립 코스 섹션
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
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
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
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
    );
  }
}
