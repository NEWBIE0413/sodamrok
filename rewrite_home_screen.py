from pathlib import Path

content = """import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/spacing.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const double _navHeight = 72;
  static const double _appBarHeight = 64;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topOffset = media.padding.top + _appBarHeight;
    final bottomOffset = media.padding.bottom + _navHeight;

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
          const _MapBackdrop(),
          Positioned.fill(
            top: topOffset,
            bottom: bottomOffset,
            child: const _FeedSheet(),
          ),
        ],
      ),
    );
  }
}

class _MapBackdrop extends StatelessWidget {
  const _MapBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFBACFCA),
            Color(0xFF8EB4AC),
            Color(0xFF5F938A),
          ],
        ),
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Container(
            padding: const EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                Text(
                  'Map Preview',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Gaps.xs,
                Text(
                  '실시간 지도 영역',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedSheet extends StatelessWidget {
  const _FeedSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.28,
      minChildSize: 0.22,
      maxChildSize: 1.0,
      snap: true,
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
                child: ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(Insets.md, Insets.sm, Insets.md, Insets.lg),
                  itemBuilder: (context, index) {
                    final post = _MockFeed.posts[index];
                    return _FeedPostCard(post: post);
                  },
                  separatorBuilder: (_, __) => const Divider(
                    height: Insets.lg * 2,
                    color: Color(0xFFE0D8CF),
                  ),
                  itemCount: _MockFeed.posts.length,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeedPostCard extends StatelessWidget {
  const _FeedPostCard({required this.post});

  final _FeedPost post;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withOpacity(0.15),
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
                  post.author,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                  ),
                ),
                Text(
                  post.timeAgo,
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
            post.photoPlaceholder,
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
      ],
    );
  }
}

class _FeedPost {
  const _FeedPost({
    required this.author,
    required this.timeAgo,
    required this.caption,
    required this.photoPlaceholder,
    this.tags = const [],
  });

  final String author;
  final String timeAgo;
  final String caption;
  final String photoPlaceholder;
  final List<String> tags;

  String get authorInitial => author.isNotEmpty ? author.substring(0, 1) : '?';
}

class _MockFeed {
  static const posts = <_FeedPost>[
    _FeedPost(
      author: '소담 라이프',
      timeAgo: '5분 전',
      caption: '햇살 좋은 소담 카페에서 2시간 집중! 북카페 느낌 최고였어요.',
      photoPlaceholder: 'Photo Placeholder',
      tags: ['소담카페', '햇살좋아요', '집중시간'],
    ),
    _FeedPost(
      author: '미선',
      timeAgo: '30분 전',
      caption: '친구와 함께 브런치 → 산책 → 북살롱 코스 완주!',
      photoPlaceholder: 'Photo Placeholder',
      tags: ['브런치', '산책', '북살롱'],
    ),
    _FeedPost(
      author: '라이프 기록가',
      timeAgo: '1시간 전',
      caption: '밤하늘이 예쁜 길 위의 도서관. 야간 독서 추천 코스입니다.',
      photoPlaceholder: 'Photo Placeholder',
      tags: ['야간산책', '도서관', '조용한시간'],
    ),
  ];
}
"""

Path('frontend/sodamrok/lib/features/home/presentation/home_screen.dart').write_text(content, encoding="utf8")
