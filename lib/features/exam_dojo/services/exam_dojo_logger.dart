import 'dart:convert';
import 'dart:developer' as developer;

/// Lightweight logger to trace Exam Dojo creation across layers.
class ExamDojoLogger {
  ExamDojoLogger._();

  static const String _logName = 'ExamDojo';

  /// Emits a structured log entry with a timestamp and optional payload.
  static void log(String stage, {Map<String, dynamic>? details}) {
    final entry = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'stage': stage,
      if (details != null && details.isNotEmpty) 'details': details,
    };
    developer.log(
      const JsonEncoder.withIndent('  ').convert(entry),
      name: _logName,
    );
  }
}
