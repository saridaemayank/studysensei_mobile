import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import 'sensei_review_screen.dart';

class CameraScreen extends StatefulWidget {
  final String subject;
  final String concept;

  const CameraScreen({Key? key, required this.subject, required this.concept})
    : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late final BackendService _backendService;
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isProcessing = false;
  int _recordingDuration = 0;
  double _uploadProgress = 0.0;
  Timer? _timer;
  List<CameraDescription> _cameras = [];

  @override
  void initState() {
    super.initState();
    _backendService = BackendService(user: FirebaseAuth.instance.currentUser);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw Exception('No cameras found');
      }
      _controller = CameraController(
        _cameras.first,
        ResolutionPreset.high,
        enableAudio: true,
      );
      await _controller!.initialize();
      setState(() => _isInitialized = true);
    } catch (e) {
      if (mounted) {
        _showError('Failed to initialize camera: $e');
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;

    try {
      setState(() => _isInitialized = false);
      await _controller!.dispose();

      final currentCameraIndex = _cameras.indexOf(_controller!.description);
      final newCameraIndex = (currentCameraIndex + 1) % _cameras.length;

      _controller = CameraController(
        _cameras[newCameraIndex],
        ResolutionPreset.high,
        enableAudio: true,
      );

      await _controller!.initialize();
      setState(() => _isInitialized = true);
    } catch (e) {
      _showError('Failed to switch camera: $e');
      setState(() => _isInitialized = true);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingDuration++;
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _startRecording() async {
    if (!_isInitialized || _isRecording) return;

    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });
      _startTimer();
    } catch (e) {
      _showError('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    File? tempVideoFile;

    try {
      setState(() {
        _isProcessing = true;
        _uploadProgress = 0.0;
      });
      _stopTimer();

      // Stop the recording and get the temp file
      final videoFile = await _controller!.stopVideoRecording();
      tempVideoFile = File(videoFile.path);

      if (!mounted) return;

      // Upload directly to Firebase Storage
      final downloadUrl = await _backendService.uploadVideo(
        tempVideoFile,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
      );

      if (!mounted) return;

      // Navigate to review screen with the download URL
      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SenseiReviewScreen(
              subject: widget.subject,
              concept: widget.concept,
              isFaceBlurred: false,
              isMuted: false,
              duration: _recordingDuration,
              videoUrl: downloadUrl,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to upload video: $e');
        setState(() {
          _isProcessing = false;
          _isRecording = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildCameraPreview() {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Positioned.fill(
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: CameraPreview(_controller!),
          ),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Uploading video... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          )
        else if (_isRecording)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
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
                  const SizedBox(width: 6),
                  Text(
                    '${(_recordingDuration ~/ 60).toString().padLeft(2, '0')}:${(_recordingDuration % 60).toString().padLeft(2, '0')}',
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
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _isRecording ? _stopRecording : _startRecording,
      backgroundColor: _isRecording ? Colors.red : Colors.blue,
      icon: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record),
      label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Your Lesson'),
        actions: [
          if (_cameras.length > 1)
            IconButton(
              icon: const Icon(Icons.switch_camera),
              onPressed: _isProcessing ? null : _toggleCamera,
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_isInitialized && _controller != null)
            CameraPreview(_controller!),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Processing your video...\nThis may take a moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isProcessing ? null : _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
