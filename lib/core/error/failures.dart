import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;
  
  const Failure(this.message, {this.statusCode});
  
  @override
  List<Object?> get props => [message, statusCode];
  
  @override
  String toString() => '$runtimeType: $message';
}

class ServerFailure extends Failure {
  const ServerFailure(String message, {int? statusCode}) : super(message, statusCode: statusCode);
}

class CacheFailure extends Failure {
  const CacheFailure(String message) : super(message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(String message) : super(message);
}

class ValidationFailure extends Failure {
  final Map<String, List<String>>? errors;
  
  const ValidationFailure(String message, {this.errors}) : super(message);
  
  @override
  List<Object?> get props => [message, errors];
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(String message) : super(message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(String message) : super(message);
}

class UnexpectedFailure extends Failure {
  final dynamic error;
  
  const UnexpectedFailure(String message, {this.error}) : super(message);
  
  @override
  List<Object?> get props => [message, error];
}
