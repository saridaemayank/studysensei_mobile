import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

import '../models/livekit_credentials.dart';
import '../models/sensei_session.dart';

/// Service class for handling backend operations with Firebase Cloud Functions
class BackendService {
  static const String _baseUrl =
      'https://us-central1-study-sensei-53462.cloudfunctions.net/analyzeVideoWithMemory';
  static const String _satoriSessionUrl =
      'https://us-central1-study-sensei-53462.cloudfunctions.net/api/api/satori/token';
  // Firebase services
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final User? user;

  BackendService({required this.user});

  /// Uploads a video file to Firebase Storage and returns the download URL
  Future<String> uploadVideo(
    File videoFile, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final userId = user?.uid;
      if (userId == null) {
        throw Exception('User must be authenticated to upload videos');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'videos/$userId/session_$timestamp.mp4';

      print('📁 Uploading video to: $fileName');
      print('📂 Video path: ${videoFile.path}');

      // Check if file exists and is not empty
      if (!await videoFile.exists()) {
        throw Exception('Video file does not exist at path: ${videoFile.path}');
      }

      final fileSize = await videoFile.length();
      if (fileSize == 0) {
        throw Exception('Video file is empty (0 bytes)');
      }

      print(
        '📏 File size: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB',
      );

      // Get a reference to the location where we'll upload the file
      final storageRef = _storage.ref().child(fileName);

      // Create file metadata including the content type
      final metadata = SettableMetadata(
        contentType: 'video/mp4',
        customMetadata: {
          'uploadedBy': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'originalName': videoFile.path.split('/').last,
        },
      );

      // Start the upload
      final uploadTask = storageRef.putFile(videoFile, metadata);

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('📤 Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
        onProgress?.call(progress);
      });

      // Wait for the upload to complete
      final taskSnapshot = await uploadTask;

      // Get the download URL
      final downloadUrl = await taskSnapshot.ref.getDownloadURL();
      print('✅ Video uploaded successfully');
      print('🔗 Download URL: $downloadUrl');

      // Return the download URL
      return downloadUrl;
    } catch (e, stackTrace) {
      print('❌ Error uploading video: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to upload video: $e');
    }
  }

  /// Processes a video and creates a new learning session
  Future<SenseiSession> processVideo({
    required File videoFile,
    required String subject,
    required String concept,
    void Function(double progress)? onUploadProgress,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      if (user == null) {
        throw Exception('User must be authenticated to process videos');
      }

      print('🚀 Starting video processing for concept: $concept');

      // Check if file exists and is readable
      if (!await videoFile.exists()) {
        throw Exception('Video file does not exist at path: ${videoFile.path}');
      }

      final fileSize = await videoFile.length();
      print('📂 Video file path: ${videoFile.path}');
      print(
        '📏 File size: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB',
      );

      if (fileSize == 0) {
        throw Exception('Video file is empty (0 bytes)');
      }

      // 1. Upload video to Firebase Storage
      print('📤 Uploading video to Firebase Storage...');
      String videoUrl;
      try {
        videoUrl = await uploadVideo(
          videoFile,
          onProgress: onUploadProgress,
        ).timeout(const Duration(minutes: 5));
        print('✅ Video uploaded successfully');
        print('🔗 Download URL: $videoUrl');
      } catch (e) {
        throw Exception('Failed to upload video: $e');
      }

      // Generate lesson using the uploaded video
      print('🎬 Generating lesson from video...');
      return await generateLesson(
        videoUrl: videoUrl,
        subject: subject,
        concept: concept,
      );
    } catch (e, stackTrace) {
      print('❌ Error in processVideo: $e');
      rethrow;
    }
  }

  /// Requests LiveKit connection credentials for the Satori doubt solver agent.
  ///
  /// The Cloud Function should:
  ///  * validate the user's Firebase ID token
  ///  * create or reuse a LiveKit room for the session
  ///  * dispatch the Satori agent worker if needed
  ///  * return a JSON payload with `url` and `token` fields
  Future<LiveKitCredentials> createSatoriSession({
    required String subject,
    required String concept,
    String? roomName,
  }) async {
    try {
      final currentUser = user;
      if (currentUser == null) {
        throw Exception('You need to be signed in to start a Satori session.');
      }

      final displayName = currentUser.displayName?.trim();

      final uri = Uri.parse(_satoriSessionUrl).replace(
        queryParameters: {
          'identity': currentUser.uid,
          if (displayName != null && displayName.isNotEmpty)
            'name': displayName,
          'ttl': '3600',
          // Instruct backend to dispatch the Satori agent worker for this user.
          'agent': 'true',
          if (roomName != null && roomName.isNotEmpty) 'roomName': roomName,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw HttpException(
          'Failed to create Satori session (status ${response.statusCode})',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Unexpected response format while creating Satori session.',
        );
      }

      final success = decoded['success'];
      if (success is bool && !success) {
        final dispatch = decoded['dispatch'];
        final message = dispatch is Map && dispatch['message'] is String
            ? dispatch['message'] as String
            : 'Failed to dispatch Satori agent.';
        throw Exception(message);
      }

      return LiveKitCredentials.fromJson(decoded);
    } catch (e, stackTrace) {
      log('Failed to create Satori LiveKit session: $e',
          stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Generates a lesson using the video URL and returns a session
  /// Extracts quiz questions from the API response
  List<Map<String, dynamic>> _extractQuizQuestions(dynamic data) {
    try {
      if (data is! Map<String, dynamic>) return [];

      final questions = <Map<String, dynamic>>[];

      // Check for different possible question formats in the response
      if (data['questions'] is List) {
        // Format 1: questions array
        for (var q in data['questions']) {
          if (q is Map<String, dynamic>) {
            questions.add({
              'question': q['question']?.toString().trim() ?? 'No question',
              'options': List<String>.from(
                q['options']?.map((o) => o.toString().trim()) ?? [],
              ),
              'correctAnswer':
                  q['correctAnswer'] is int ? q['correctAnswer'] : 0,
              'explanation': q['explanation']?.toString().trim() ?? '',
            });
          }
        }
      } else if (data['quiz'] is Map && data['quiz']['questions'] is List) {
        // Format 2: quiz.questions array
        for (var q in data['quiz']['questions']) {
          if (q is Map<String, dynamic>) {
            questions.add({
              'question': q['question']?.toString().trim() ?? 'No question',
              'options': List<String>.from(
                q['options']?.map((o) => o.toString().trim()) ?? [],
              ),
              'correctAnswer':
                  q['correctAnswer'] is int ? q['correctAnswer'] : 0,
              'explanation': q['explanation']?.toString().trim() ?? '',
            });
          }
        }
      }

      return questions;
    } catch (e) {
      print('Error extracting quiz questions: $e');
      return [];
    }
  }

  /// Creates a session from the API response data
  SenseiSession _createSessionFromApiResponse(
    Map<String, dynamic> data, {
    required String videoUrl,
    required String subject,
    required String concept,
  }) {
    try {
      // Handle content which could be a list or a string
      final content = data['content'] is List
          ? (data['content'] as List).map((e) => e.toString()).toList()
          : [data['content']?.toString() ?? ''];

      // Handle summary which could be a list or a string
      final summary = data['summary'] is List
          ? (data['summary'] as List).map((e) => e.toString()).join('\n')
          : data['summary']?.toString() ?? '';

      // Get analysis from data or fall back to joined content
      final analysis = data['analysis']?.toString() ?? content.join('\n\n');

      print('\n📊 SESSION DATA:');
      print('Analysis length: ${analysis.length} characters');
      print('Summary length: ${summary.length} characters');
      print('Content paragraphs: ${content.length}');

      return SenseiSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        subject: subject,
        concepts: [concept],
        videoUrl: videoUrl,
        title: data['title']?.toString() ?? concept,
        summary: summary.isNotEmpty ? summary : analysis,
        analysis: analysis,
        quizQuestions: List<Map<String, dynamic>>.from(
          data['quiz_questions'] ?? [],
        ),
        isProcessed: true,
      );
    } catch (e, stackTrace) {
      print('❌ Error creating session: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<SenseiSession> generateLesson({
    required String videoUrl,
    required String subject,
    required String concept,
  }) async {
    try {
      print('🚀 Starting lesson generation for concept: $concept');
      print('📹 Using video URL: $videoUrl');

      // 1. Get user token
      print('🔑 Getting user ID token...');
      final idToken = await user!.getIdToken(true);
      if (idToken == null) {
        throw Exception('❌ Failed to get authentication token');
      }
      print('✅ Successfully retrieved ID token');

      // 2. Prepare the request
      final requestBody = {
        'topic': concept,
        'firebaseStorageUrl': _convertToGsUrl(videoUrl),
      };

      print('📤 Sending request to analyze video...');

      // 3. Call the API
      final stopwatch = Stopwatch()..start();
      final response = await http.post(
        Uri.parse(
          'https://us-central1-study-sensei-53462.cloudfunctions.net/analyzeVideo',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(requestBody),
      );
      stopwatch.stop();

      print(
        '📥 API Response (${stopwatch.elapsedMilliseconds}ms): ${response.statusCode}',
      );

      if (response.statusCode != 200) {
        throw Exception(
          '❌ API Error (${response.statusCode}): ${response.body}',
        );
      }

      // 4. Parse the raw response
      print('\n📋 RAW RESPONSE:');
      print(response.body);

      final data = jsonDecode(response.body);

      // 5. Validate response structure
      if (data is! Map<String, dynamic>) {
        throw Exception('❌ Invalid response format: Expected a JSON object');
      }

      // 6. Extract and log the main content sections
      print('\n📝 EXTRACTING CONTENT SECTIONS...');

      // Extract content from the response
      final List<String> contentList = (data['content'] is List)
          ? (data['content'] as List).map((e) => e.toString().trim()).toList()
          : [];

      // Extract summary points
      final List<String> summaryList = (data['summary'] is List)
          ? (data['summary'] as List).map((e) => e.toString().trim()).toList()
          : [];

      // Join content and summary for display
      final String content = contentList.join('\n\n');
      final String summary = summaryList.join('\n• ');

      print('\n📄 CONTENT (${content.length} chars):');
      print('----------------------------------------');
      print(content.isNotEmpty ? content : 'No content available');

      print('\n📌 SUMMARY (${summary.length} chars):');
      print('----------------------------------------');
      print(summary.isNotEmpty ? summary : 'No summary available');

      // 7. Extract and log questions
      print('\n❓ EXTRACTING QUIZ QUESTIONS...');
      final List<Map<String, dynamic>> questions = [];

      if (data['questions'] is List) {
        for (var q in data['questions']) {
          if (q is Map<String, dynamic>) {
            // Convert answer from 'A', 'B', 'C', etc. to index (0, 1, 2, ...)
            final answer = q['answer']?.toString().toUpperCase() ?? '';
            int correctAnswer = 0;
            if (answer.isNotEmpty) {
              correctAnswer = answer.codeUnitAt(0) - 'A'.codeUnitAt(0);
            }

            questions.add({
              'question': q['question']?.toString().trim() ?? 'No question',
              'options': (q['options'] is List)
                  ? (q['options'] as List)
                      .map((e) => e.toString().trim())
                      .toList()
                  : <String>[],
              'correctAnswer': correctAnswer,
              'explanation': q['explanation']?.toString().trim() ?? '',
            });
          }
        }
      }

      // 8. Log extracted questions
      if (questions.isNotEmpty) {
        print('✅ Found ${questions.length} questions:');
        questions.asMap().forEach((i, q) {
          print('\n  ${i + 1}. ${q['question']}');
          if (q['options'] is List) {
            (q['options'] as List).asMap().forEach((j, opt) {
              print(
                '     ${j + 1}. $opt${j == q['correctAnswer'] ? ' ✅' : ''}',
              );
            });
          }
          if ((q['explanation'] as String).isNotEmpty) {
            print('     💡 Explanation: ${q['explanation']}');
          }
        });
      } else {
        print('ℹ️ No questions found in the response');
      }

      // 9. Create the session with all extracted data
      print('\n📦 CREATING SESSION OBJECT...');
      final session = _createSessionFromApiResponse(
        {
          ...data,
          'content': contentList, // Store as list to maintain structure
          'summary': summaryList, // Store as list to maintain structure
          'quiz_questions': questions,
        },
        videoUrl: videoUrl,
        subject: subject,
        concept: concept,
      );

      // Log the extracted data for debugging
      print('\n✅ EXTRACTED DATA:');
      print('Content paragraphs: ${contentList.length}');
      print('Summary points: ${summaryList.length}');
      print('Questions found: ${questions.length}');

      // Print first few items of each section
      print('\n📄 FIRST FEW CONTENT PARAGRAPHS:');
      contentList.take(3).forEach((para) => print('- $para'));

      if (questions.isNotEmpty) {
        print('\n❓ FIRST QUESTION:');
        final q = questions.first;
        print('Q: ${q['question']}');
        (q['options'] as List).asMap().forEach((i, opt) {
          print(
            '  ${String.fromCharCode(65 + i)}. $opt${i == q['correctAnswer'] ? ' ✅' : ''}',
          );
        });
        if ((q['explanation'] as String).isNotEmpty) {
          print('💡 ${q['explanation']}');
        }
      }

      // 10. Save the complete session ONCE
      print('\n💾 SAVING SESSION TO FIRESTORE...');
      print('Session data to save:');
      print(
        jsonEncode(session.toJson(), toEncodable: (item) => item.toString()),
      );

      final savedSession = await saveSession(session);
      print('✅ Session saved with ID: ${savedSession.id}');

      return savedSession;
    } catch (e, stackTrace) {
      print('❌ Error in generateLesson: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Converts a download URL to gs:// format
  String _convertToGsUrl(String downloadUrl) {
    try {
      print('Converting download URL to gs:// URL:');
      print('Original URL: $downloadUrl');

      // If it's already a gs:// URL, return as is
      if (downloadUrl.startsWith('gs://')) {
        print('Already a gs:// URL, returning as is');
        return downloadUrl;
      }

      // Parse the download URL
      final uri = Uri.parse(downloadUrl);

      // Check if this is a Firebase Storage download URL
      if (uri.host.contains('firebasestorage.googleapis.com')) {
        // The path should be in format: /v0/b/BUCKET_NAME/o/PATH/TO/FILE
        final pathSegments = uri.pathSegments;
        if (pathSegments.length >= 4 &&
            pathSegments[0] == 'v0' &&
            pathSegments[1] == 'b' &&
            pathSegments[3] == 'o') {
          final bucket = pathSegments[2];
          final filePath = pathSegments.sublist(4).join('/');
          final gsUrl = 'gs://$bucket/$filePath';
          print('Converted to gs:// URL: $gsUrl');
          return gsUrl;
        }
      }

      // For other URLs, try to extract bucket and path from the host and path
      if (uri.host.isNotEmpty && uri.path.isNotEmpty) {
        final bucket = uri.host.split('.').first;
        // Remove any query parameters and fragments
        final path =
            uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
        final gsUrl = 'gs://$bucket/$path';
        print('Converted to gs:// URL (fallback): $gsUrl');
        return gsUrl;
      }

      throw Exception('Could not convert URL to gs:// format');
    } catch (e, stackTrace) {
      print('❌ Error converting URL: $e');
      print('Stack trace: $stackTrace');
      // If we can't convert it, return the original and let the server handle it
      return downloadUrl;
    }
  }

  // Removed duplicate _handleApiError method

  /// Saves a session to Firestore
  Future<SenseiSession> saveSession(SenseiSession session) async {
    try {
      if (user == null) {
        throw Exception('User must be authenticated to save sessions');
      }

      final sessionData = session.toJson();
      final sessionRef = _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('sessions')
          .doc(session.id);

      await sessionRef.set(sessionData, SetOptions(merge: true));

      // Return the session with the updated ID
      return session.copyWith(id: sessionRef.id);
    } catch (e) {
      print('Error saving session: $e');
      rethrow;
    }
  }

  /// Fetches a session by its ID
  Future<SenseiSession> getSession(String sessionId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/sessions/$sessionId'),
      );

      if (response.statusCode == 200) {
        return SenseiSession.fromJson(jsonDecode(response.body));
      } else {
        throw _handleApiError(response);
      }
    } catch (e) {
      throw _handleError('Failed to fetch session', e);
    }
  }

  /// Fetches all sessions for the current user from Firestore
  Future<List<SenseiSession>> getUserSessions() async {
    try {
      final userId = user?.uid;
      if (userId == null) {
        return [];
      }

      print('Fetching sessions for user: $userId');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('sessions')
          .orderBy('createdAt', descending: true)
          .get();

      print('Found ${querySnapshot.docs.length} sessions');

      return querySnapshot.docs.map((doc) {
        try {
          final data = doc.data();
          // Ensure the document ID is included in the data
          data['id'] = doc.id;
          return SenseiSession.fromJson(data);
        } catch (e) {
          print('Error parsing session ${doc.id}: $e');
          // Return a default session with error information
          return SenseiSession(
            id: doc.id,
            subject: 'Error',
            concepts: ['Error loading session'],
            createdAt: DateTime.now(),
            isFaceBlurred: false,
            isMuted: false,
          );
        }
      }).toList();
    } catch (e) {
      print('Error fetching user sessions: $e');
      rethrow;
    }
  }

  /// Updates a session with new data
  Future<SenseiSession> updateSession({
    required String sessionId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/sessions/$sessionId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await user?.getIdToken() ?? ''}',
        },
        body: jsonEncode(updates),
      );

      if (response.statusCode == 200) {
        return SenseiSession.fromJson(jsonDecode(response.body));
      } else {
        throw _handleApiError(response);
      }
    } catch (e) {
      throw _handleError('Failed to update session', e);
    }
  }

  /// Deletes a session
  Future<void> deleteSession(String sessionId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/sessions/$sessionId'),
        headers: {'Authorization': 'Bearer ${await user?.getIdToken() ?? ''}'},
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw _handleApiError(response);
      }
    } catch (e) {
      throw _handleError('Failed to delete session', e);
    }
  }

  // Helper method to handle API errors
  Exception _handleApiError(http.Response response) {
    try {
      final error = jsonDecode(response.body);
      return Exception(
        error['message']?.toString() ?? 'API Error: ${response.statusCode}',
      );
    } catch (e) {
      return Exception('API Error: ${response.statusCode} - ${response.body}');
    }
  }

  // Helper method to handle general errors
  Exception _handleError(String message, dynamic error) {
    if (error is Exception) return error;
    return Exception('$message: $error');
  }
}
