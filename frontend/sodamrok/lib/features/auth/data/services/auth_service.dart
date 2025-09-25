import 'package:dio/dio.dart';

import '../../../../core/network/dio_client.dart';
import '../../domain/models/auth_tokens.dart';
import '../../domain/models/auth_user.dart';

class AuthService {
  AuthService(this._client);

  final DioClient _client;

  Dio get _dio => _client.dio;

  Future<(AuthTokens, AuthUser)> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/token/',
      data: {
        'email': email,
        'password': password,
      },
    );

    final data = response.data ?? <String, dynamic>{};
    final tokens = AuthTokens.fromJson(data);
    final userJson = data['user'] as Map<String, dynamic>? ?? const {};
    final user = AuthUser.fromJson(userJson);
    return (tokens, user);
  }

  Future<AuthUser> register({
    required String email,
    required String password,
    String? displayName,
    String? nickname,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/users/',
      data: {
        'email': email,
        'password': password,
        if (displayName != null && displayName.isNotEmpty) 'display_name': displayName,
        if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
      },
    );
    final data = response.data ?? <String, dynamic>{};
    return AuthUser.fromJson(data);
  }

  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    await _dio.post<void>(
      '/auth/reset-password/',
      data: {
        'email': email,
        'new_password': newPassword,
      },
    );
  }

  Future<AuthTokens> refresh(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/token/refresh/',
      data: {'refresh': refreshToken},
    );
    final data = response.data ?? <String, dynamic>{};
    final access = data['access'] as String?;
    if (access == null || access.isEmpty) {
      throw const FormatException('토큰을 재발급하는 데 실패했습니다.');
    }
    return AuthTokens(accessToken: access, refreshToken: refreshToken);
  }

  Future<AuthUser> fetchProfile() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/users/me/');
    final data = response.data ?? <String, dynamic>{};
    return AuthUser.fromJson(data);
  }
}
