enum DoubtErrorCode {
  invalidRequest,
  unauthorized,
  imageUnreadable,
  mediaProcessingFailed,
  aiTimeout,
  aiResponseInvalid,
  internalError,
  network,
  timeout,
  malformedResponse,
  unsupportedVersion,
  cancelled;

  static DoubtErrorCode fromBackend(String? code) => switch (code) {
        'INVALID_REQUEST' => invalidRequest,
        'UNAUTHORIZED' => unauthorized,
        'IMAGE_UNREADABLE' => imageUnreadable,
        'MEDIA_PROCESSING_FAILED' => mediaProcessingFailed,
        'AI_TIMEOUT' => aiTimeout,
        'AI_RESPONSE_INVALID' => aiResponseInvalid,
        _ => internalError,
      };
}

/// Contains only controlled, student-safe copy, never a server exception.
class SenseiDoubtError implements Exception {
  final DoubtErrorCode code;
  const SenseiDoubtError(this.code);
  String get message => switch (code) {
        DoubtErrorCode.unauthorized =>
          'Your session has expired. Sign in again and retry.',
        DoubtErrorCode.imageUnreadable =>
          "I couldn't read this clearly. Try taking a closer photo or selecting a smaller area.",
        DoubtErrorCode.mediaProcessingFailed =>
          "I couldn't process this image. Try another photo.",
        DoubtErrorCode.aiTimeout ||
        DoubtErrorCode.timeout =>
          'Sensei took too long on this one. Please try again.',
        DoubtErrorCode.network =>
          "Couldn't reach Sensei. Check your connection and try again.",
        DoubtErrorCode.invalidRequest =>
          'Please check your image and selection, then try again.',
        DoubtErrorCode.unsupportedVersion =>
          'Please update StudySensei to view this response.',
        DoubtErrorCode.cancelled => 'Request cancelled.',
        _ => 'Sensei had trouble understanding this one. Please try again.',
      };
  @override
  String toString() => 'SenseiDoubtError(${code.name})';
}
