import 'package:dio/dio.dart';

import '../../../../core/network/dio_client.dart';

class PostLikeResult {
  const PostLikeResult({required this.liked, required this.likeCount});

  final bool liked;
  final int likeCount;
}

class PostInteractionService {
  const PostInteractionService(this._client);

  final DioClient _client;

  Dio get _dio => _client.dio;

  Future<PostLikeResult> toggleLike({
    required String postId,
    required bool isLiked,
  }) async {
    final method = isLiked ? 'DELETE' : 'POST';
    final response = await _dio.request<Map<String, dynamic>>(
      '/v1/posts/$postId/like/',
      options: Options(method: method),
    );
    final data = response.data ?? <String, dynamic>{};
    final liked = data['liked'] as bool? ?? !isLiked;
    final likeCount = (data['like_count'] as num?)?.toInt() ?? 0;
    return PostLikeResult(liked: liked, likeCount: likeCount);
  }

  Future<void> createComment({
    required String postId,
    required String content,
  }) async {
    await _dio.post<void>(
      '/v1/posts/$postId/comments/',
      data: {'content': content},
    );
  }
}
