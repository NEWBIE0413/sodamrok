import 'package:flutter/material.dart';

import '../core/config/environment.dart';
import '../core/dependencies/app_dependencies.dart';
import '../core/theme/app_theme.dart';
import '../shared/utils/spacing.dart';
import 'package:sodamrok/app/widgets/top_bar.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/home/presentation/home_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  late final List<Widget> _pages;
  late final List<PreferredSizeWidget> _topBars;

  @override
  void initState() {
    super.initState();
    final authController = AppDependencies.authController;
    _pages = [
      const HomeScreen(),
      const _PlaceholderPage(
        title: '트립 준비 중',
        description: '추천 플로우와 저장된 코스를 이곳에 구성합니다.',
      ),
      const _PlaceholderPage(
        title: '검색 준비 중',
        description: '장소·태그 탐색 UI가 여기에 배치됩니다.',
      ),
      _ProfilePage(controller: authController),
    ];

    _topBars = [
      TopBar.home(
        onSearchTap: _showSearchPlaceholder,
        onNotificationsTap: _showNotificationsPlaceholder,
      ),
      TopBar.placeholder('트립'),
      TopBar.placeholder('검색'),
      TopBar.placeholder('프로필'),
    ];
  }

  void _showSearchPlaceholder() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('검색 기능을 준비 중이에요.')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: _topBars[_index],
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: Color(0xFFE4E0D8), width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          height: 72,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.map_rounded), label: '탐색'),
            NavigationDestination(icon: Icon(Icons.auto_awesome_rounded), label: '트립'),
            NavigationDestination(icon: Icon(Icons.search_rounded), label: '검색'),
            NavigationDestination(icon: Icon(Icons.person_rounded), label: '프로필'),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title, required this.description});

  final String title;
  final String description;



  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: const Color(0xFFE0D8CF)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              Gaps.md,
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.controller});

  final AuthController controller;



  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final user = controller.user;
        final isAuthenticating = controller.status == AuthStatus.authenticating;
        final isLoggedIn = controller.isAuthenticated;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          child: Center(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: const Color(0xFFE0D8CF)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '프로필',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                  Gaps.md,
                  if (user != null) ...[
                    _ProfileInfoRow(label: '이메일', value: user.email),
                    if (user.displayName.isNotEmpty)
                      _ProfileInfoRow(label: '이름', value: user.displayName),
                    if (user.nickname.isNotEmpty)
                      _ProfileInfoRow(label: '닉네임', value: user.nickname),
                  ] else ...[
                    const Text(
                      '로그인 후 프로필을 확인할 수 있어요.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                  Gaps.md,
                  ElevatedButton(
                    onPressed: isAuthenticating
                        ? null
                        : (isLoggedIn ? controller.logout : () => _openLogin(context)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3A7D74),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(isLoggedIn ? '로그아웃' : '로그인하기'),
                  ),
                  if (Environment.useMockFeed) ...[
                    Gaps.md,
                    const Text(
                      'Mock 피드 모드가 활성화되어 있습니다.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openLogin(BuildContext context) async {
    await showLoginModal(context, controller);
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({required this.label, required this.value});

  final String label;
  final String value;



  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textMain),
            ),
          ),
        ],
      ),
    );
  }
}


