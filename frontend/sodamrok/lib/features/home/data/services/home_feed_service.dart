import 'package:dio/dio.dart';

import '../../../../core/network/dio_client.dart';
import '../../domain/exceptions/home_feed_exception.dart';
import '../../domain/models/home_feed_post.dart';
import '../../domain/repositories/home_feed_repository.dart';

class HomeFeedService implements HomeFeedRepository {
  HomeFeedService(this._client);

  final DioClient _client;

  @override
  Future<HomeFeedData> fetchFeed() async {
    try {
      final response = await _client.dio.get<dynamic>('/v1/posts/');
      final items = _extractItems(response.data);
      final posts = items.map(_mapPost).toList(growable: false);
      return HomeFeedData(posts: posts);
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      final message = switch (statusCode) {
        401 => '로그인이 필요해요. 다시 로그인 해주세요.',
        403 => '접근 권한이 없어요.',
        _ => '피드를 불러오는 중 문제가 발생했어요.',
      };
      throw HomeFeedException(message, statusCode: statusCode);
    } on HomeFeedException {
      rethrow;
    } catch (_) {
      throw const HomeFeedException('피드를 불러오지 못했어요. 잠시 후 다시 시도해주세요.');
    }
  }

  List<Map<String, dynamic>> _extractItems(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList(growable: false);
    }

    if (raw is Map<String, dynamic>) {
      final results = raw['results'];
      if (results is List) {
        return results.whereType<Map<String, dynamic>>().toList(growable: false);
      }
    }

    throw const HomeFeedException('피드 응답 형식이 올바르지 않아요.');
  }

  HomeFeedPost _mapPost(Map<String, dynamic> json) {
    final title = (json['title'] as String?)?.trim() ?? '';
    final body = (json['body'] as String?)?.trim() ?? '';
    final createdAt = _parseDateTime(json['created_at'] as String?);
    final mediaUrls = (json['media_urls'] as List?)?.whereType<String>().toList() ?? const <String>[];
    final tags = _parseTags(json['tags']);

    var authorName = '나';
    final author = json['author'];
    if (author is Map<String, dynamic>) {
      final nickname = (author['nickname'] as String?)?.trim();
      final displayName = (author['display_name'] as String?)?.trim();
      if (nickname != null && nickname.isNotEmpty) {
        authorName = nickname;
      } else if (displayName != null && displayName.isNotEmpty) {
        authorName = displayName;
      }
    } else {
      final candidate = (json['author_name'] as String?)?.trim();
      if (candidate != null && candidate.isNotEmpty) {
        authorName = candidate;
      }
    }

    final likeCount = (json['like_count'] as num?)?.toInt() ?? 0;
    final commentCount = (json['comment_count'] as num?)?.toInt() ?? 0;
    final isLiked = json['is_liked'] as bool? ?? false;

    return HomeFeedPost(
      id: json['id']?.toString() ?? '',
      authorName: authorName,
      authorInitial: _initialFrom(authorName),
      timeAgoLabel: _formatRelativeTime(createdAt),
      caption: body.isNotEmpty ? body : (title.isNotEmpty ? title : '새로운 기록을 남겨보세요.'),
      mediaLabel: mediaUrls.isEmpty ? '미디어 없음' : '사진 ${mediaUrls.length}장',
      tags: tags,
      likeCount: likeCount,
      commentCount: commentCount,
      isLiked: isLiked,
    );
  }

  List<String> _parseTags(dynamic raw) {
    if (raw is List) {
      return raw
          .map((tag) {
            if (tag is Map<String, dynamic>) {
              final name = tag['name'];
              if (name is String && name.isNotEmpty) {
                return name;
              }
            } else if (tag is String && tag.isNotEmpty) {
              return tag;
            }
            return null;
          })
          .whereType<String>()
          .toList();
    }
    return const <String>[];
  }

  DateTime? _parseDateTime(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toLocal();
  }

  String _formatRelativeTime(DateTime? timestamp) {
    if (timestamp == null) {
      return '';
    }

    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return '방금 전';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}분 전';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}시간 전';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}일 전';
    }
    if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()}주 전';
    }
    return '${(diff.inDays / 30).floor()}달 전';
  }

  String _initialFrom(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    final codePoint = trimmed.runes.first;
    return String.fromCharCode(codePoint);
  }
}
