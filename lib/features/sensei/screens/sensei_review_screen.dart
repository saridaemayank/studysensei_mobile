import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import '../services/backend_service.dart';

import '../models/sensei_session.dart';
import '../widgets/language_voice_picker.dart';
import 'sensei_generate_screen.dart';
import '../services/tts_service.dart';

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
  bool _isPlayingTts = false;

  late final TtsService _ttsService = TtsService()..init();

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
      body: Stack(
        children: [
          _isGenerating
              ? _buildGeneratingView(theme)
              : _buildReviewView(theme, colorScheme),

          // TTS Button - Fixed at bottom right
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'tts_button',
              onPressed: _toggleTts,
              backgroundColor: colorScheme.primary,
              child: Icon(
                _isPlayingTts ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Video player controller
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

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
    // Start video initialization in the background
    _initializeVideoPlayer();
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

  @override
  void dispose() {
    _disposeVideoControllers();
    _ttsService.dispose();
    super.dispose();
  }

  Future<void> _disposeVideoControllers() async {
    try {
      if (_chewieController != null) {
        _chewieController!.dispose();
        _chewieController = null;
      }
      if (_videoPlayerController != null) {
        await _videoPlayerController!.dispose();
        _videoPlayerController = null;
      }
    } catch (e) {
      debugPrint('Error disposing video controllers: $e');
    }
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      final videoUrl = widget.videoUrl ?? widget.session?.videoUrl;
      if (videoUrl == null || videoUrl.isEmpty) {
        debugPrint('ℹ️ No video URL provided for preview');
        return;
      }

      debugPrint('🔄 Initializing video player with URL: $videoUrl');

      // Dispose of existing controllers if any
      await _disposeVideoControllers();

      try {
        // Initialize video controller with basic configuration
        _videoPlayerController = VideoPlayerController.network(
          videoUrl,
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: false,
          ),
        );

        // Set volume and initialize with timeout
        await _videoPlayerController!.setVolume(1.0);

        await _videoPlayerController!.initialize().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('⚠️ Video initialization timed out');
            return _videoPlayerController!;
          },
        );

        if (_videoPlayerController!.value.isInitialized) {
          debugPrint('✅ Video player initialized successfully');
          if (mounted) {
            setState(() {});
          }
        }
      } catch (e) {
        debugPrint('⚠️ Video initialization failed: $e');
        // Don't show error to user, video is optional
      }
    } catch (e) {
      debugPrint('❌ Error in _initializeVideoPlayer: $e');
    }
  }

  Future<void> _toggleTts() async {
    try {
      if (_isPlayingTts) {
        await _ttsService.stop();
        if (mounted) {
          setState(() => _isPlayingTts = false);
        }
      } else {
        // Get the first available content to speak
        final textToSpeak =
            widget.session?.analysis ??
            widget.session?.summary ??
            widget.session?.narrationScript ??
            '';

        if (textToSpeak.isNotEmpty) {
          await _ttsService.speak(textToSpeak);
          if (mounted) {
            setState(() => _isPlayingTts = true);
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No content available to read')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling TTS: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: ${e.toString()}')),
        );
      }
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
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child:
                        _videoPlayerController != null &&
                            _videoPlayerController!.value.isInitialized
                        ? Chewie(controller: _chewieController!)
                        : Container(
                            color: Colors.black,
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                  ),
                  // TTS button removed from here - will be added at the bottom of the screen
                ],
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
                      // TTS button removed from here - will be added at the bottom of the screen
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
                      // TTS button removed from here - will be added at the bottom of the screen
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
            child: FilledButton.icon(
              onPressed: _generateLesson,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Generate Lesson'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
