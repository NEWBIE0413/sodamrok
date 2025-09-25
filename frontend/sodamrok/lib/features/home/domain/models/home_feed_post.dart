class HomeFeedPost {
  const HomeFeedPost({
    required this.id,
    required this.authorName,
    required this.authorInitial,
    required this.timeAgoLabel,
    required this.caption,
    required this.mediaLabel,
    this.tags = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
  });

  final String id;
  final String authorName;
  final String authorInitial;
  final String timeAgoLabel;
  final String caption;
  final String mediaLabel;
  final List<String> tags;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
}
