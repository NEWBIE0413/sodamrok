import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/spacing.dart';
import '../data/repositories/mock_home_feed_repository.dart';
import '../domain/models/home_feed_post.dart';
import '../domain/repositories/home_feed_repository.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        children: const [
          _MapBackdrop(),
          Positioned.fill(child: _FeedSheet()),
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

class _FeedSheet extends StatefulWidget {
  const _FeedSheet({this.repository = const MockHomeFeedRepository()});

  final HomeFeedRepository repository;

  static const double _collapsedHeight = 136;

  @override
  State<_FeedSheet> createState() => _FeedSheetState();
}

class _FeedSheetState extends State<_FeedSheet> {
  late Future<HomeFeedData> _feedFuture;

  @override
  void initState() {
    super.initState();
    _feedFuture = widget.repository.fetchFeed();
  }

  void _reload() {
    setState(() {
      _feedFuture = widget.repository.fetchFeed();
    });
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
                            return _FeedError(onRetry: _reload);
                          }

                          final posts = snapshot.data?.posts ?? const <HomeFeedPost>[];

                          if (posts.isEmpty) {
                            return const _FeedEmpty();
                          }

                          return ListView.separated(
                            controller: controller,
                            padding: EdgeInsets.fromLTRB(
                              Insets.md,
                              Insets.sm,
                              Insets.md,
                              Insets.lg + bottomInset,
                            ),
                            itemBuilder: (context, index) {
                              final post = posts[index];
                              return _FeedPostCard(post: post);
                            },
                            separatorBuilder: (_, __) => const Divider(
                              height: Insets.lg * 2,
                              color: Color(0xFFE0D8CF),
                            ),
                            itemCount: posts.length,
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
}

class _FeedPostCard extends StatelessWidget {
  const _FeedPostCard({required this.post});

  final HomeFeedPost post;

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
  const _FeedError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '피드를 불러오지 못했어요.',
            style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w600),
          ),
          Gaps.sm,
          TextButton(
            onPressed: onRetry,
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
        '아직 피드가 없어요. 곧 새로운 기록을 준비할게요!',
        style: TextStyle(color: AppColors.textSecondary),
        textAlign: TextAlign.center,
      ),
    );
  }
}
