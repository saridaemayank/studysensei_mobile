import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../data/models/exam_dojo_subject.dart';
import 'exam_dojo_logger.dart';

class ExamDojoApiService {
  ExamDojoApiService({FirebaseAuth? auth, http.Client? client})
      : _auth = auth ?? FirebaseAuth.instance,
        _client = client ?? http.Client();

  static const String _baseUrl =
      'https://us-central1-study-sensei-53462.cloudfunctions.net/api';

  final FirebaseAuth _auth;
  final http.Client _client;

  Future<Map<String, dynamic>> createDojo({
    required String name,
    required String timezone,
    String? description,
    List<String>? memberIds,
    List<ExamDojoSubject>? subjects,
  }) async {
    final token = await _getIdToken();
    final payload = <String, dynamic>{
      'name': name,
      'timezone': timezone,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (memberIds != null && memberIds.isNotEmpty) 'memberIds': memberIds,
      if (subjects != null && subjects.isNotEmpty)
        'subjects': subjects.map(_subjectToApiMap).toList(),
    };

    ExamDojoLogger.log(
      'api.createDojo.request',
      details: {
        'url': '$_baseUrl/exam-dojos',
        'payload': payload,
      },
    );
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/exam-dojos'),
          headers: _headers(token),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = _decodeResponse(response);
    ExamDojoLogger.log(
      'api.createDojo.response',
      details: {
        'status': response.statusCode,
        'dojoKeys': decoded.keys.toList(),
      },
    );
    return decoded;
  }

  Future<Map<String, dynamic>> updateDojo({
    required String dojoId,
    String? name,
    String? description,
    String? timezone,
  }) async {
    final token = await _getIdToken();
    final payload = <String, dynamic>{
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (timezone != null) 'timezone': timezone,
    };

    final response = await _client
        .patch(
          Uri.parse('$_baseUrl/exam-dojos/$dojoId'),
          headers: _headers(token),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> addSubject({
    required String dojoId,
    required ExamDojoSubject subject,
  }) async {
    final token = await _getIdToken();
    final payload = _subjectToApiMap(subject);
    ExamDojoLogger.log(
      'api.addSubject.request',
      details: {
        'dojoId': dojoId,
        'payload': payload,
      },
    );
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/exam-dojos/$dojoId/subjects'),
          headers: _headers(token),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = _decodeResponse(response);
    ExamDojoLogger.log(
      'api.addSubject.response',
      details: {
        'status': response.statusCode,
        'subjectId': decoded['id'] ?? decoded['subjectId'],
      },
    );
    return decoded;
  }

  Future<Map<String, dynamic>> generateRoadmap({
    required String dojoId,
    required DateTime studyWindowStart,
    required DateTime studyWindowEnd,
    required int weeklyLoadMinutes,
    String? notes,
  }) async {
    final token = await _getIdToken();
    final payload = <String, dynamic>{
      'studyWindowStart': studyWindowStart.toIso8601String(),
      'studyWindowEnd': studyWindowEnd.toIso8601String(),
      'weeklyLoadMinutes': weeklyLoadMinutes,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };

    ExamDojoLogger.log(
      'api.generateRoadmap.request',
      details: {
        'dojoId': dojoId,
        'payload': payload,
      },
    );
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/exam-dojos/$dojoId/roadmap:generate'),
          headers: _headers(token),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = _decodeResponse(response);
    ExamDojoLogger.log(
      'api.generateRoadmap.response',
      details: {
        'status': response.statusCode,
        'roadmapVersion': decoded['version'],
        'blockSummary': decoded['studyBlocksSummary'],
      },
    );
    return decoded;
  }

  Future<List<Map<String, dynamic>>> generateDailyBlocks({
    required String dojoId,
    required DateTime date,
    required String timezone,
  }) async {
    final token = await _getIdToken();
    final payload = <String, dynamic>{
      'date': _formatDateOnly(date),
      'timezone': timezone,
    };

    ExamDojoLogger.log(
      'api.generateDailyBlocks.request',
      details: {
        'dojoId': dojoId,
        'payload': payload,
      },
    );
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/exam-dojos/$dojoId/daily-blocks:generate'),
          headers: _headers(token),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));

    final data = _decodeResponse(response);
    ExamDojoLogger.log(
      'api.generateDailyBlocks.response',
      details: {
        'status': response.statusCode,
        'dojoId': dojoId,
        'blockCount': (data['blocks'] as List?)?.length ?? 0,
      },
    );
    final blocks = data['blocks'];
    if (blocks is List) {
      return blocks.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  Map<String, dynamic> _subjectToApiMap(ExamDojoSubject subject) {
    final chapters = _chaptersToApiPayload(subject);
    return {
      'id': subject.id,
      'name': subject.name,
      'examDate': subject.examDate.toIso8601String(),
      if (chapters.isNotEmpty) 'chapters': chapters,
      if (subject.estimatedEffort != null)
        'estimatedEffort': subject.estimatedEffort,
      if (subject.difficulty != null) 'difficulty': subject.difficulty,
    };
  }

  List<Map<String, dynamic>> _chaptersToApiPayload(
    ExamDojoSubject subject,
  ) {
    return subject.chapters.asMap().entries.map((entry) {
      final index = entry.key;
      final rawTitle = entry.value.trim();
      final resolvedTitle = rawTitle.isEmpty ? 'Untitled Chapter' : rawTitle;
      final chapterId = '${subject.id}-ch-$index';
      return {
        'id': chapterId,
        'chapterId': chapterId,
        'title': resolvedTitle,
        'name': resolvedTitle,
        'chapterName': resolvedTitle,
        'weight': 1,
        'expectedMinutes': 60,
        'isCore': false,
        'sequence': index + 1,
      };
    }).toList();
  }

  Map<String, String> _headers(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  String _formatDateOnly(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<dynamic> _getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.getIdToken();
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data;
  }
}
