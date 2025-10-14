import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import '../services/backend_service.dart';

import '../models/sensei_session.dart';
import '../widgets/language_voice_picker.dart';
import 'sensei_generate_screen.dart';

class SenseiReviewScreen extends StatefulWidget {
  final String subject;
  final String concept;
  final bool isFaceBlurred;
  final bool isMuted;
  final int duration;
  final String? videoUrl;
  final SenseiSession? session;

  const SenseiReviewScreen({
    super.key,
    required this.subject,
    required this.concept,
    required this.isFaceBlurred,
    required this.isMuted,
    required this.duration,
    this.videoUrl,
    this.session,
  });

  @override
  State<SenseiReviewScreen> createState() => _SenseiReviewScreenState();
}

class _SenseiReviewScreenState extends State<SenseiReviewScreen> {
  List<String> _detectedObjects = [];
  String _selectedLanguage = 'English';
  String _selectedVoice = 'Default Voice';
  bool _isGenerating = false;
  double _generationProgress = 0.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Your Lesson'),
        actions: [
          if (_isGenerating)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isGenerating
          ? _buildGeneratingView(theme)
          : _buildReviewView(theme, colorScheme),
    );
  }

  // Helper method to safely get progress value for LinearProgressIndicator
  double _getSafeProgressValue(double progress) {
    if (progress.isNaN || progress.isInfinite || progress < 0) return 0.0;
    if (progress > 1.0) return 1.0;
    return progress;
  }

  // Helper method to safely calculate progress percentage
  int _getProgressPercentage(double progress) {
    if (progress.isNaN || progress.isInfinite || progress < 0) return 0;
    if (progress > 1.0) return 100;
    return (progress * 100).toInt();
  }

  @override
  void initState() {
    super.initState();
    _loadDetectedObjects();
  }

  Future<void> _loadDetectedObjects() async {
    try {
      // This will be populated by the actual API response
      // For now, we'll keep it empty
      if (!mounted) return;

      // Only update if we have actual data from the API
      if (widget.session?.conceptMappings?.isNotEmpty == true) {
        setState(() {
          _detectedObjects = widget.session!.conceptMappings!
              .map((mapping) => mapping['concept']?.toString() ?? '')
              .where((concept) => concept.isNotEmpty)
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading detected objects: $e');
    }
  }

  void _onLanguageVoiceChanged(String language, String voice) {
    if (mounted) {
      setState(() {
        _selectedLanguage = language;
        _selectedVoice = voice;
      });
    }
  }

  Future<void> _generateLesson() async {
    if (!mounted || _isGenerating) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait for the operation to complete'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() {
      _isGenerating = true;
      _generationProgress = 0.0;
    });

    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to generate lessons'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Get the video URL from either the session or widget
      final videoUrl = widget.session?.videoUrl ?? widget.videoUrl;
      if (videoUrl == null || videoUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No video available for processing'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      setState(() => _generationProgress = 0.1);

      debugPrint('Starting lesson generation with video: $videoUrl');
      debugPrint('Subject: ${widget.subject}, Concept: ${widget.concept}');

      // Call the API to process the video
      setState(() => _generationProgress = 0.3);
      debugPrint('Initiating video analysis...');

      // Create a temporary file from the video URL
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/temp_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );

      // Download the video from the URL
      final response = await http.get(Uri.parse(videoUrl));
      await tempFile.writeAsBytes(response.bodyBytes);

      // Process the video using the BackendService
      final backendService = BackendService(user: user);
      final subject = widget.subject;
      final concept = widget.concept;

      debugPrint('Starting lesson generation with video: $videoUrl');
      debugPrint('Subject: $subject, Concept: $concept');

      try {
        // Process the video and get the complete session with all data
        final session = await backendService.processVideo(
          videoFile: tempFile,
          subject: subject,
          concept: concept,
          onUploadProgress: (progress) {
            if (mounted) {
              setState(() {
                // Update progress between 0.3 and 0.9 (30% to 90%) for upload and processing
                _generationProgress = 0.3 + (progress * 0.6);
              });
            }
          },
        );

        debugPrint('Video analysis completed successfully');
        debugPrint('Generated session ID: ${session.id}');

        // Check if the response indicates an error
        if (session.analysis?.toLowerCase().contains('error') == true) {
          throw Exception('Error from API: ${session.analysis}');
        }

        if (!mounted) return;

        // Navigate to the generate screen with the new session
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SenseiGenerateScreen.fromRouteArgs(session),
          ),
        );
      } catch (e) {
        debugPrint('Error processing video: $e');
        if (mounted) {
          // Show error message to user
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error processing video. Please try again.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        // Rethrow to be caught by the outer catch block
        rethrow;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  // Build the generating view with progress indicator
  // Build the generating view with progress indicator
  Widget _buildGeneratingView(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated progress circle
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withOpacity(0.1),
                  ),
                ),
                // Progress circle
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: _generationProgress,
                    strokeWidth: 4,
                    backgroundColor: theme.dividerColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
                // Center icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                  ),
                  child: Icon(
                    _getGenerationStepIcon(_generationProgress),
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _getGenerationStepText(_generationProgress),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'This usually takes about 30 seconds...',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value: _getSafeProgressValue(_generationProgress),
            backgroundColor: theme.dividerColor,
            color: theme.colorScheme.primary,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(
            '${_getProgressPercentage(_generationProgress)}% complete',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  // Build the main review view with all content
  // Build the main review view with all content
  Widget _buildReviewView(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video player
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: colorScheme.surfaceVariant,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_circle_outline,
                          size: 48,
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Summary section
          if (widget.session?.summary?.isNotEmpty ?? false) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Summary',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.session!.summary!,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Analysis section
          if (widget.session?.analysis?.isNotEmpty ?? false) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Analysis',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.session!.analysis!,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Key Concepts section - Only show if we have concepts from the API
          if (_detectedObjects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Key Concepts:',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _detectedObjects
                        .map(
                          (concept) => Chip(
                            label: Text(concept),
                            backgroundColor: colorScheme.primaryContainer,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),

          // Hook section
          if (widget.session?.hook?.isNotEmpty ?? false) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hook',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.session!.hook!,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Language and voice picker
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: LanguageVoicePicker(
              initialLanguage: _selectedLanguage,
              initialVoice: _selectedVoice,
              onChanged: _onLanguageVoiceChanged,
            ),
          ),

          // Generate button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: FilledButton(
                onPressed: _generateLesson,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Generate Lesson'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getGenerationStepIcon(double progress) {
    if (progress < 0.3) {
      return Icons.analytics_outlined;
    } else if (progress < 0.6) {
      return Icons.auto_awesome_motion;
    } else if (progress < 0.9) {
      return Icons.auto_awesome_outlined;
    } else {
      return Icons.check_circle_outline;
    }
  }

  String _getGenerationStepText(double progress) {
    if (progress < 0.3) {
      return 'Analyzing your video...';
    } else if (progress < 0.6) {
      return 'Generating lesson content...';
    } else if (progress < 0.9) {
      return 'Adding interactive elements...';
    } else {
      return 'Finalizing your lesson...';
    }
  }
}
