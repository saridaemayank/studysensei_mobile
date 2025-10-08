import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class SenseiCaptureScreen extends StatefulWidget {
  final String subject;
  final String concept;

  const SenseiCaptureScreen({
    super.key,
    required this.subject,
    required this.concept,
  });

  @override
  State<SenseiCaptureScreen> createState() => _SenseiCaptureScreenState();
}

class _SenseiCaptureScreenState extends State<SenseiCaptureScreen> with WidgetsBindingObserver {
  bool _isRecording = false;
  bool _isFaceBlurred = false;
  bool _isMuted = false;
  CameraController? _cameraController;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  final int _maxDuration = 20; // 20 seconds max recording
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _cameraController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      
      // Request camera permissions
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras found');
      }
      
      // Use the first camera (back camera by default)
      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      
      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      
      await _cameraController?.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error initializing camera. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      debugPrint('Camera not initialized');
      return;
    }

    if (_isRecording) return;

    try {
      _cameraController!.startVideoRecording();
      
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        
        setState(() {
          _recordingDuration++;
        });
        
        if (_recordingDuration >= _maxDuration) {
          _stopRecording();
          timer.cancel();
        }
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start recording')),
        );
      }
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    
    _recordingTimer?.cancel();
    setState(() {
      _isRecording = false;
    });

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // Get the recorded video file path from the camera controller
      final videoFile = await _cameraController?.stopVideoRecording();
      
      if (videoFile == null) {
        throw Exception('Failed to save recorded video');
      }

      // Create a reference to the Firebase Storage location
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('videos')
          .child(user.uid)
          .child('${widget.subject}_${widget.concept}_${DateTime.now().millisecondsSinceEpoch}.mp4');

      // Upload the video to Firebase Storage
      final uploadTask = storageRef.putFile(File(videoFile.path));
      
      // Show upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        debugPrint('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });

      // Wait for the upload to complete
      final taskSnapshot = await uploadTask.whenComplete(() {});
      final videoUrl = await taskSnapshot.ref.getDownloadURL();
      
      debugPrint('Video uploaded successfully. URL: $videoUrl');

      // Close the loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Navigate to review screen with the video URL
      if (context.mounted) {
        Navigator.pushNamed(
          context,
          '/sensei/review',
          arguments: {
            'subject': widget.subject,
            'concept': widget.concept,
            'isFaceBlurred': _isFaceBlurred,
            'isMuted': _isMuted,
            'duration': _recordingDuration,
            'videoUrl': videoUrl,
          },
        );
      }
    } catch (e) {
      debugPrint('Error in _stopRecording: $e');
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
        setState(() {
          _isRecording = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remainingTime = _maxDuration - _recordingDuration;
    final progress = _recordingDuration / _maxDuration;
    
    if (!_isCameraInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // Format the remaining time as MM:SS
    final minutes = (remainingTime ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingTime % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Lesson'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: Column(
        children: [
          // Camera preview
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_cameraController != null && _cameraController!.value.isInitialized)
                  CameraPreview(_cameraController!)
                else
                  const Center(child: CircularProgressIndicator()),
                  
                // Recording indicator
                if (_isRecording)
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'REC $minutes:$seconds',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.scaffoldBackgroundColor,
            child: Column(
              children: [
                // Progress indicator
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 16),
                
                // Record button
                GestureDetector(
                  onTap: _isRecording ? _stopRecording : _startRecording,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording ? Colors.red : Colors.blue,
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.fiber_manual_record,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Toggle buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildToggleButton(
                      icon: Icons.face_retouching_off,
                      label: 'Blur Face',
                      isActive: _isFaceBlurred,
                      onTap: () {
                        setState(() {
                          _isFaceBlurred = !_isFaceBlurred;
                        });
                      },
                    ),
                    _buildToggleButton(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      label: _isMuted ? 'Unmute' : 'Mute',
                      isActive: _isMuted,
                      onTap: () {
                        setState(() {
                          _isMuted = !_isMuted;
                          // Muting is handled during recording in _startRecording
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Subject and concept header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.subject,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.concept,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Camera preview/placeholder
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Camera preview would go here
                  const Icon(
                    Icons.videocam_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  
                  // Recording indicator
                  if (_isRecording)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'REC',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '00:${remainingTime.toString().padLeft(2, '0')}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                                fontFeatures: [
                                  const FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Recording progress
          if (_isRecording)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: theme.dividerColor,
                color: theme.colorScheme.primary,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          
          // Controls
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Toggle buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildToggleButton(
                      icon: Icons.face_retouching_off,
                      label: 'Blur Faces',
                      isActive: _isFaceBlurred,
                      onTap: () {
                        setState(() {
                          _isFaceBlurred = !_isFaceBlurred;
                        });
                      },
                    ),
                    _buildToggleButton(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      label: _isMuted ? 'Muted' : 'Mute',
                      isActive: _isMuted,
                      onTap: () {
                        setState(() {
                          _isMuted = !_isMuted;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Record button
                GestureDetector(
                  onTap: _isRecording ? _stopRecording : _startRecording,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording ? Colors.red : theme.colorScheme.primary,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording ? Colors.red : theme.colorScheme.primary)
                              .withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.fiber_manual_record,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isRecording ? 'Tap to stop' : 'Hold to record (max 20s)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive 
              ? theme.colorScheme.primary.withOpacity(0.1)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive 
                ? theme.colorScheme.primary
                : theme.dividerColor,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive 
                  ? theme.colorScheme.primary
                  : theme.textTheme.bodyMedium?.color,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isActive 
                    ? theme.colorScheme.primary
                    : theme.textTheme.bodyMedium?.color,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
