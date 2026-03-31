/// Custom exceptions for data layer
class ServerException implements Exception {
  final String message;
  final String? code;
  const ServerException({required this.message, this.code});

  @override
  String toString() => 'ServerException: $message (code: $code)';
}

class CacheException implements Exception {
  final String message;
  const CacheException({required this.message});

  @override
  String toString() => 'CacheException: $message';
}

class AuthException implements Exception {
  final String message;
  final String? code;
  const AuthException({required this.message, this.code});

  @override
  String toString() => 'AuthException: $message (code: $code)';
}

class NetworkException implements Exception {
  final String message;
  const NetworkException({this.message = 'No internet connection'});

  @override
  String toString() => 'NetworkException: $message';
}
