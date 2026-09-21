import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../common/widgets/sensei_primary_button.dart';

/// Redesigned Camera Screen (Phase 3).
/// Purpose: "Capture the thing you're stuck on."
/// Fast, calm, nearly full-screen camera with minimal dark translucent controls,
/// subtle guide overlay, flash toggle, and tactile shutter.
class CameraScreen extends StatefulWidget {
  final String subject;
  final String concept;
  final void Function(XFile photo)? onPhotoCaptured;
  final List<CameraDescription>? availableCamerasOverride;

  const CameraScreen({
    super.key,
    required this.subject,
    required this.concept,
    this.onPhotoCaptured,
    this.availableCamerasOverride,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _isCapturing = false;
  bool _showShutterFlash = false;
  FlashMode _flashMode = FlashMode.off;
  bool _initializing = false;
  bool _active = true;
  bool _completed = false;
  bool _changingFlash = false;
  int _generation = 0;
  Future<void> _release = Future<void>.value();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  // Detach immediately; serialize native disposal before creating another camera.
  void _releaseCamera() {
    _generation++;
    final controller = _controller;
    _controller = null;
    _isInitialized = false;
    if (controller != null) {
      _release = _release.then((_) async {
        try {
          await controller.dispose();
        } catch (_) {
          // A disconnected camera may already have been released by the OS.
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _active = false;
    _releaseCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (!_active) {
      _releaseCamera();
      if (mounted) setState(() {});
    } else if (!_completed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted || !_active || _completed || _initializing) return;
    _initializing = true;
    _releaseCamera();
    final generation = _generation;
    bool current() => mounted && _active && generation == _generation;
    setState(() => _errorMessage = null);
    try {
      await _release;
      if (!current()) return;
      if (_cameras.isEmpty) {
        _cameras = widget.availableCamerasOverride ?? await availableCameras();
        if (!current()) return;
        final back = _cameras.indexWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
        );
        _selectedCameraIndex = back < 0 ? 0 : back;
      }
      if (_cameras.isEmpty) {
        setState(() => _errorMessage = "Camera isn't available right now.");
        return;
      }
      final controller = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = controller;
      await controller.initialize();
      if (!current()) return;
      // Flash support differs across lenses. It must not block the preview.
      try {
        await controller.setFlashMode(FlashMode.off);
      } on CameraException catch (_) {
        // Some cameras have no flash hardware.
      }
      if (!current()) return;
      setState(() {
        _flashMode = FlashMode.off;
        _isInitialized = true;
      });
    } catch (error) {
      if (!current()) return;
      final denied = error is CameraException &&
          const {
            'CameraAccessDenied',
            'CameraAccessDeniedWithoutPrompt',
            'CameraAccessRestricted',
          }.contains(error.code);
      _releaseCamera();
      setState(() {
        _errorMessage = denied
            ? 'Camera access is needed to take a photo.'
            : "Couldn't start the camera.";
      });
    } finally {
      _initializing = false;
      // Resume may arrive while a previous initialization is still finishing.
      if (mounted &&
          _active &&
          !_completed &&
          generation != _generation &&
          _errorMessage == null) {
        unawaited(_initializeCamera());
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (!_isInitialized || _isCapturing || _changingFlash) return;
    final controller = _controller!;
    _changingFlash = true;

    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.off:
        nextMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
      default:
        nextMode = FlashMode.off;
        break;
    }

    try {
      await controller.setFlashMode(nextMode);
      if (mounted && identical(controller, _controller)) {
        setState(() {
          _flashMode = nextMode;
        });
      }
    } catch (_) {
      // Flash mode may not be supported on all cameras
    } finally {
      _changingFlash = false;
    }
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.auto:
        return Icons.flash_auto_rounded;
      case FlashMode.always:
        return Icons.flash_on_rounded;
      case FlashMode.off:
      default:
        return Icons.flash_off_rounded;
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 ||
        _isCapturing ||
        _initializing ||
        _changingFlash) {
      return;
    }

    final nextIndex = (_selectedCameraIndex + 1) % _cameras.length;
    setState(() {
      _selectedCameraIndex = nextIndex;
      _isInitialized = false;
    });

    await _initializeCamera();
  }

  Future<void> _capturePhoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing ||
        _completed ||
        !_active ||
        _changingFlash) {
      return;
    }

    final generation = _generation;
    setState(() {
      _isCapturing = true;
      _showShutterFlash = true;
    });

    // Shutter flash feedback duration
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) {
        setState(() {
          _showShutterFlash = false;
        });
      }
    });

    try {
      final XFile photo = await _controller!.takePicture();

      if (!mounted) return;

      if (generation != _generation || !_active) return;
      _deliverPhoto(photo);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't take the photo. Try again."),
            backgroundColor: AppColors.surfaceElevated,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _openGallery() async {
    if (_isCapturing || _completed) return;
    setState(() => _isCapturing = true);

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (image != null && mounted) {
        _deliverPhoto(image);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not access gallery.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _deliverPhoto(XFile photo) {
    if (!mounted || _completed || ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    _completed = true;
    _releaseCamera();
    if (widget.onPhotoCaptured != null) {
      widget.onPhotoCaptured!(photo);
    } else {
      Navigator.of(context).pop(photo);
    }
  }

  Widget _buildTopControls(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Close / Back button
              _buildCircularButton(
                icon: Icons.close_rounded,
                onTap: () => Navigator.of(context).maybePop(),
                tooltip: 'Close',
              ),
              // Flash button
              _buildCircularButton(
                icon: _getFlashIcon(),
                onTap: _isInitialized && !_isCapturing ? _toggleFlash : null,
                tooltip: 'Flash Mode',
                color: _flashMode != FlashMode.off
                    ? AppColors.primaryLight
                    : Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideOverlay() {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 80,
      left: 20,
      right: 20,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xB307111F), // 70% dark navy
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.borderSubtle,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Point at your doubt',
                style: AppTypography.cardTitle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'You can select the exact part next.',
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding:
              const EdgeInsets.only(left: 32, right: 32, bottom: 24, top: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Gallery Shortcut
              SizedBox(
                width: 52,
                height: 52,
                child: _buildCircularButton(
                  icon: Icons.photo_library_rounded,
                  onTap: _isCapturing ? null : _openGallery,
                  tooltip: 'Choose from Gallery',
                  size: 52,
                  iconSize: 24,
                ),
              ),

              // Center: Large Tactile Shutter Button
              Semantics(
                label: 'Take photo',
                button: true,
                enabled: _isInitialized && !_isCapturing,
                child: GestureDetector(
                  onTap: _isCapturing || !_isInitialized ? null : _capturePhoto,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary,
                        width: 3.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.primaryGlow,
                          blurRadius: 18,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        width: _isCapturing ? 54 : 60,
                        height: _isCapturing ? 54 : 60,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Right: Camera Switcher (or placeholder if only 1 camera)
              SizedBox(
                width: 52,
                height: 52,
                child: _cameras.length > 1
                    ? _buildCircularButton(
                        icon: Icons.flip_camera_ios_rounded,
                        onTap: _switchCamera,
                        tooltip: 'Switch Camera',
                        size: 52,
                        iconSize: 24,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback? onTap,
    String? tooltip,
    Color color = Colors.white,
    double size = 44,
    double iconSize = 20,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0x66000000), // 40% black
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.borderSubtle,
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: const Icon(
                Icons.videocam_off_rounded,
                size: 32,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _errorMessage ?? "Camera isn't available right now.",
              textAlign: TextAlign.center,
              style: AppTypography.cardTitle.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 24),
            SenseiPrimaryButton(
              width: 180,
              height: 48,
              text: 'Try Again',
              onPressed: _initializeCamera,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    if (_completed || !_active) return const SizedBox.expand();
    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (!_isInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    // Calculate aspect ratio
    double previewRatio = _controller!.value.aspectRatio;
    if (MediaQuery.orientationOf(context) == Orientation.portrait) {
      previewRatio = 1 / previewRatio;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // Camera feed scaled to fill screen without stretching
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxWidth / previewRatio,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),

            // Shutter snapshot flash overlay
            if (_showShutterFlash)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 100),
                opacity: _showShutterFlash ? 0.4 : 0.0,
                child: Container(color: Colors.white),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview
          _buildPreview(context),

          // 2. Guide Overlay
          if (_isInitialized) _buildGuideOverlay(),

          // 3. Top Controls (Close, Flash)
          _buildTopControls(context),

          // 4. Bottom Controls (Gallery, Shutter, Switch)
          _buildBottomControls(),
        ],
      ),
    );
  }
}
