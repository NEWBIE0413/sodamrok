class HomeFeedPost {
  const HomeFeedPost({
    required this.id,
    required this.authorName,
    required this.authorInitial,
    required this.timeAgoLabel,
    required this.caption,
    required this.mediaLabel,
    this.tags = const [],
  });

  final String id;
  final String authorName;
  final String authorInitial;
  final String timeAgoLabel;
  final String caption;
  final String mediaLabel;
  final List<String> tags;
}
