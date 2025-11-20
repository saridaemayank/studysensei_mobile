import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kDebugMode;
import '../models/sensei_session.dart';

class SenseiApiService {
  static const String _baseUrl =
      'https://us-central1-study-sensei-53462.cloudfunctions.net/api';
  final User? user;

  // Helper method to extract sections from the analysis text
  String _extractSection(String analysis, String sectionTitle) {
    final startIndex = analysis.indexOf(sectionTitle);
    if (startIndex == -1) return '';

    final endIndex = analysis.indexOf('\n\n', startIndex);
    return endIndex == -1
        ? analysis.substring(startIndex + sectionTitle.length).trim()
        : analysis.substring(startIndex + sectionTitle.length, endIndex).trim();
  }

  // Helper method to extract concepts from the analysis
  List<String> _extractConcepts(String analysis) {
    final concepts = <String>[];
    final conceptPattern = RegExp(r'\*\*([^*]+)\*\*:([^*]+)');
    final matches = conceptPattern.allMatches(analysis);

    for (final match in matches) {
      final concept = match.group(1)?.trim() ?? '';
      if (concept.isNotEmpty) {
        concepts.add(concept);
      }
    }

    return concepts.isNotEmpty ? concepts : ['Physics', 'Motion', 'Optics'];
  }

  // Helper method to generate quiz questions from the analysis
  List<Map<String, dynamic>> _generateQuizQuestions(String analysis) {
    // This is a simplified example. In a real app, you might want to use more sophisticated
    // NLP or a dedicated quiz generation service
    return [
      {
        'question':
            'What is the main physics principle demonstrated by the motion blur in the video?',
        'options': ['Reflection', 'Refraction', 'Relative Motion', 'Gravity'],
        'correctIndex': 2,
        'explanation':
            'The motion blur demonstrates relative motion between the camera and the objects in the room.',
      },
      {
        'question':
            'What force keeps the ceiling fan blades moving in a circular path?',
        'options': [
          'Centripetal Force',
          'Gravitational Force',
          'Friction',
          'Tension',
        ],
        'correctIndex': 0,
        'explanation':
            'Centripetal force is required to keep objects moving in a circular path.',
      },
      {
        'question':
            'What type of energy conversion is happening in the fluorescent lights?',
        'options': [
          'Chemical to Light',
          'Electrical to Light',
          'Heat to Light',
          'Kinetic to Light',
        ],
        'correctIndex': 1,
        'explanation':
            'Fluorescent lights convert electrical energy into light energy.',
      },
    ];
  }

  SenseiApiService({required this.user});

  // Process video and analyze content
  // This method only analyzes the video and returns the analysis data
  // without saving to Firestore, as the BackendService handles the saving
  Future<Map<String, dynamic>> analyzeVideo({
    required String videoUrl,
    required String subject,
  }) async {
    try {
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get the Firebase ID token
      final idToken = await user!.getIdToken();

      // Convert the download URL to a storage reference path
      String storagePath = '';
      try {
        final uri = Uri.parse(videoUrl);
        final pathSegments = uri.path.split('/');

        // Find the index of 'b' which is before the bucket name
        final bIndex = pathSegments.indexOf('b');
        if (bIndex == -1 || bIndex + 1 >= pathSegments.length) {
          throw Exception('Invalid Firebase Storage URL format');
        }

        final bucket = pathSegments[bIndex + 1];

        // Find the index of 'o' which is before the file path
        final oIndex = pathSegments.indexOf('o', bIndex);
        if (oIndex == -1 || oIndex + 1 >= pathSegments.length) {
          throw Exception('Invalid Firebase Storage URL format');
        }

        // Get the file path and decode URL-encoded characters
        final filePath = pathSegments.sublist(oIndex + 1).join('/');
        final decodedPath = Uri.decodeFull(filePath);

        storagePath = 'gs://$bucket/$decodedPath';
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing video URL: $e');
        }
        throw Exception('Invalid video URL format');
      }

      final url =
          'https://us-central1-study-sensei-53462.cloudfunctions.net/analyzeVideo';

      final requestBody = {
        'topic': subject, // Using subject as topic
        'firebaseStorageUrl': storagePath,
      };

      if (kDebugMode) {
        print('Calling analyzeVideo function with URL: $url');
        print(
          'Request headers: ${{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken'
          }}',
        );
        print('Request body: ${jsonEncode(requestBody)}');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(requestBody),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Check if the response contains the expected analysis
        if (responseData['success'] == true &&
            responseData.containsKey('analysis')) {
          return responseData;
        } else {
          throw Exception('Invalid response format from API');
        }
      } else {
        throw Exception(
          'Failed to process video: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      print('Error in analyzeVideo: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Get all sessions for the current user
  Stream<List<SenseiSession>> getUserSessions() {
    if (user == null) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('sessions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError(
          (_) {},
          test: (error) =>
              error is FirebaseException && error.code == 'permission-denied',
        )
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => SenseiSession.fromJson({
                  ...doc.data() as Map<String, dynamic>,
                  'id': doc.id,
                }),
              )
              .toList(),
        );
  }

  // Get a specific session by ID for the current user
  Future<SenseiSession?> getSessionById(String sessionId) async {
    if (user == null) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('sessions')
          .doc(sessionId)
          .get();

      if (!doc.exists) return null;

      // Get the document data
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;

      // Convert timestamps to ISO strings
      final sessionData = Map<String, dynamic>.from(data);

      if (sessionData['createdAt'] != null &&
          sessionData['createdAt'] is Timestamp) {
        sessionData['createdAt'] =
            (sessionData['createdAt'] as Timestamp).toDate().toIso8601String();
      }

      if (sessionData['updatedAt'] != null &&
          sessionData['updatedAt'] is Timestamp) {
        sessionData['updatedAt'] =
            (sessionData['updatedAt'] as Timestamp).toDate().toIso8601String();
      }

      return SenseiSession.fromJson({...sessionData, 'id': doc.id, ...data});
    } catch (e, stackTrace) {
      print('Error fetching session from Firestore:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
