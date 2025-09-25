import '../models/home_feed_post.dart';

class HomeFeedData {
  const HomeFeedData({required this.posts});

  final List<HomeFeedPost> posts;
}

abstract class HomeFeedRepository {
  Future<HomeFeedData> fetchFeed();
}
