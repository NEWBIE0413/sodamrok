class HomeFeedException implements Exception {
  const HomeFeedException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
