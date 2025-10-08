import 'exceptions.dart';
import 'failures.dart';

Failure mapExceptionToFailure(dynamic exception) {
  if (exception is ServerException) {
    return ServerFailure(
      exception.message,
      statusCode: exception.statusCode,
    );
  } else if (exception is CacheException) {
    return CacheFailure(exception.message);
  } else if (exception is NotFoundException) {
    return NotFoundFailure(exception.message);
  } else if (exception is ValidationException) {
    return ValidationFailure(
      exception.message,
      errors: exception.errors,
    );
  } else if (exception is UnauthorizedException) {
    return UnauthorizedFailure(exception.message);
  } else if (exception is NetworkException) {
    return NetworkFailure(exception.message);
  } else {
    return UnexpectedFailure(
      'Unexpected error occurred',
      error: exception,
    );
  }
}

String getErrorMessage(Failure failure) {
  if (failure is ValidationFailure && failure.errors != null) {
    // Return the first error message from the first field with errors
    final firstErrorField = failure.errors!.entries.first;
    return '${firstErrorField.key}: ${firstErrorField.value.first}';
  }
  return failure.message;
}
