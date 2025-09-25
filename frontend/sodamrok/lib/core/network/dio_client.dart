import 'package:dio/dio.dart';

class DioClient {
  DioClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Dio get dio => _dio;

  void addInterceptor(Interceptor interceptor) {
    _dio.interceptors.add(interceptor);
  }

  void configure({required String baseUrl, Map<String, dynamic>? headers}) {
    final mergedHeaders = <String, dynamic>{
      'Content-Type': 'application/json',
    };

    if (headers != null && headers.isNotEmpty) {
      mergedHeaders.addAll(headers);
    }

    _dio.options = BaseOptions(
      baseUrl: baseUrl,
      headers: mergedHeaders,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
    );
  }

  void setAuthToken(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
      return;
    }
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }
}
