import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/home/presentation/home_screen.dart';
import '../shared/utils/spacing.dart';
import 'widgets/top_bar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeScreen(),
      const _PlaceholderPage(
        title: '트립 준비 중',
        description: '추천 플로우와 저장된 코스를 이곳에 구성합니다.',
      ),
      const _PlaceholderPage(
        title: '검색 준비 중',
        description: '장소·태그 탐색 UI가 여기에 배치됩니다.',
      ),
      const _PlaceholderPage(
        title: '프로필 준비 중',
        description: '환경 설정, 친구/파티 관리 화면이 추가됩니다.',
      ),
    ];

    final topBars = <PreferredSizeWidget>[
      TopBar.home(onSearchTap: () {}),
      TopBar.placeholder('트립'),
      TopBar.placeholder('검색'),
      TopBar.placeholder('프로필'),
    ];

    return Scaffold(
      extendBody: true,
      appBar: topBars[_index],
      body: IndexedStack(
        index: _index,
        children: pages,
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
