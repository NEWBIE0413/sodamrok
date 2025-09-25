import 'dart:async';

import 'package:dio/dio.dart';

import '../../features/auth/application/auth_controller.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._authController);

  final Dio _dio;
  final AuthController _authController;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldAttemptRefresh(err)) {
      final refreshed = await _authController.refreshTokens();
      if (refreshed) {
        try {
          final response = await _retry(err.requestOptions);
          handler.resolve(response);
          return;
        } on DioException catch (retryError) {
          handler.next(retryError);
          return;
        }
      }
    }

    handler.next(err);
  }

  bool _shouldAttemptRefresh(DioException error) {
    if (error.response?.statusCode != 401) {
      return false;
    }
    final path = error.requestOptions.path;
    if (path.contains('/auth/token')) {
      return false;
    }
    return _authController.hasRefreshToken;
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) {
    final headers = Map<String, dynamic>.from(requestOptions.headers);
    final tokens = _authController.tokens;
    if (tokens != null && tokens.accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }

    return _dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: Options(
        method: requestOptions.method,
        headers: headers,
        responseType: requestOptions.responseType,
        contentType: requestOptions.contentType,
        followRedirects: requestOptions.followRedirects,
        validateStatus: requestOptions.validateStatus,
        receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
        sendTimeout: requestOptions.sendTimeout,
        receiveTimeout: requestOptions.receiveTimeout,
        extra: requestOptions.extra,
      ),
      cancelToken: requestOptions.cancelToken,
      onReceiveProgress: requestOptions.onReceiveProgress,
      onSendProgress: requestOptions.onSendProgress,
    );
  }
}
