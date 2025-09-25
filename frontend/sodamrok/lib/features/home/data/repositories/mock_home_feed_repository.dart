import 'dart:async';

import '../../domain/models/home_feed_post.dart';
import '../../domain/repositories/home_feed_repository.dart';

class MockHomeFeedRepository implements HomeFeedRepository {
  const MockHomeFeedRepository();

  @override
  Future<HomeFeedData> fetchFeed() async {
    await Future<void>.delayed(const Duration(milliseconds: 320));

    const posts = <HomeFeedPost>[
      HomeFeedPost(
        id: 'post-1',
        authorName: '소담 라이프',
        authorInitial: '소',
        timeAgoLabel: '5분 전',
        caption: '햇살 좋은 소담 카페에서 2시간 집중! 북카페 느낌 최고였어요.',
        mediaLabel: 'Photo Placeholder',
        tags: ['소담카페', '햇살좋아요', '집중시간'],
        likeCount: 12,
        commentCount: 4,
        isLiked: false,
      ),
      HomeFeedPost(
        id: 'post-2',
        authorName: '미선',
        authorInitial: '미',
        timeAgoLabel: '30분 전',
        caption: '친구와 함께 브런치 → 산책 → 북살롱 코스 완주!',
        mediaLabel: 'Photo Placeholder',
        tags: ['브런치', '산책', '북살롱'],
        likeCount: 5,
        commentCount: 2,
      ),
      HomeFeedPost(
        id: 'post-3',
        authorName: '라이프 기록가',
        authorInitial: '라',
        timeAgoLabel: '1시간 전',
        caption: '밤하늘이 예쁜 길 위의 도서관. 야간 독서 추천 코스입니다.',
        mediaLabel: 'Photo Placeholder',
        tags: ['야간산책', '도서관', '조용한시간'],
        likeCount: 8,
        commentCount: 1,
      ),
    ];

    return const HomeFeedData(posts: posts);
  }
}
