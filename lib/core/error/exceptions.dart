class ServerException implements Exception {
  final String message;
  final int? statusCode;
  
  const ServerException(this.message, {this.statusCode});
  
  @override
  String toString() => 'ServerException: $message${statusCode != null ? ' (Status Code: $statusCode)' : ''}';
}

class CacheException implements Exception {
  final String message;
  
  const CacheException(this.message);
  
  @override
  String toString() => 'CacheException: $message';
}

class NotFoundException implements Exception {
  final String message;
  
  const NotFoundException(this.message);
  
  @override
  String toString() => 'NotFoundException: $message';
}

class ValidationException implements Exception {
  final String message;
  final Map<String, List<String>>? errors;
  
  const ValidationException(this.message, {this.errors});
  
  @override
  String toString() => 'ValidationException: $message';
}

class UnauthorizedException implements Exception {
  final String message;
  
  const UnauthorizedException(this.message);
  
  @override
  String toString() => 'UnauthorizedException: $message';
}

class NetworkException implements Exception {
  final String message;
  
  const NetworkException(this.message);
  
  @override
  String toString() => 'NetworkException: $message';
}
