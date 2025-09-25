class Environment {
  Environment._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api',
  );

  static const String apiAuthToken = String.fromEnvironment(
    'API_AUTH_TOKEN',
    defaultValue: '',
  );

  static const bool useMockFeed = bool.fromEnvironment(
    'USE_MOCK_FEED',
    defaultValue: false,
  );

  static Map<String, String> defaultHeaders() {
    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (apiAuthToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiAuthToken';
    }

    return headers;
  }
}
