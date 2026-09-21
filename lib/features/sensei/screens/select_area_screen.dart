import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../common/widgets/sensei_primary_button.dart';
import '../models/focus_region.dart';
import '../models/sensei_image_selection.dart';
import '../models/sensei_help_request.dart';
import 'help_type_screen.dart';
import '../widgets/focus_region_editor.dart';

/// Keeps the image and region alive while Help Type is open.
/// Returns [SenseiHelpRequest] after Get Help, or null when going back.
class SelectAreaScreen extends StatefulWidget {
  final XFile image;
  final Future<void> Function(SenseiHelpRequest)? onGetHelp;

  const SelectAreaScreen({super.key, required this.image, this.onGetHelp});

  @override
  State<SelectAreaScreen> createState() => _SelectAreaScreenState();
}

class _SelectAreaScreenState extends State<SelectAreaScreen> {
  ui.Image? _preview;
  FocusRegion? _region;
  bool _failed = false;
  bool _loading = false;
  bool _continuing = false;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(SelectAreaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _loadVersion++;
      _loading = false;
      _preview?.dispose();
      _preview = null;
      _region = null;
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (_loading) return;
    final version = ++_loadVersion;
    setState(() {
      _loading = true;
      _failed = false;
    });
    ui.Codec? codec;
    try {
      final bytes = await widget.image.readAsBytes();
      if (!mounted || version != _loadVersion) return;
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      // Same engine codec used by Flutter ImageProviders, including supported
      // EXIF orientation handling. Only the preview is downsampled; no file writes.
      // The codec takes ownership of the buffer and disposes it.
      codec = await PaintingBinding.instance.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (width, height) => width >= height
            ? ui.TargetImageSize(width: math.min(width, 2048))
            : ui.TargetImageSize(height: math.min(height, 2048)),
      );
      final frame = await codec.getNextFrame();
      if (!mounted || version != _loadVersion) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _preview = frame.image;
        _loading = false;
      });
    } catch (_) {
      if (mounted && version == _loadVersion) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    } finally {
      codec?.dispose();
    }
  }

  @override
  void dispose() {
    _loadVersion++;
    _preview?.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_region == null || _continuing) return;
    setState(() => _continuing = true);
    final selection =
        SenseiImageSelection(image: widget.image, focusRegion: _region!);
    final request = await Navigator.of(context).push<SenseiHelpRequest>(
      MaterialPageRoute(
          builder: (_) => HelpTypeScreen(imageSelection: selection)),
    );
    if (!mounted) return;
    if (request != null) {
      if (widget.onGetHelp != null) {
        await widget.onGetHelp!(request);
        if (mounted) setState(() => _continuing = false);
      } else {
        Navigator.of(context).pop(request);
      }
    } else {
      setState(() => _continuing = false);
    }
  }

  Widget _imageArea() {
    if (_failed) {
      return Center(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.broken_image_outlined,
              color: AppColors.textSecondary, size: 36),
          const SizedBox(height: 12),
          const Text("Couldn't open this image.",
              style: AppTypography.cardTitle, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          SenseiPrimaryButton(
              text: 'Try Again', width: 180, height: 48, onPressed: _loadImage),
          TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Go Back')),
        ]),
      ));
    }
    if (_preview == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FocusRegionEditor(
      image: _preview!,
      region: _region,
      onChanged: (region) => setState(() => _region = region),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
            child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(children: [
              IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded)),
              const SizedBox(width: 4),
              const Expanded(
                  child: Text("Select what you're stuck on",
                      style: AppTypography.cardTitle)),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 2, 20, 12),
            child: Text('Drag to select the exact part.',
                style: AppTypography.bodyMedium),
          ),
          Expanded(
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _imageArea(),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                  height: 36 * MediaQuery.textScalerOf(context).scale(1),
                  child: Center(
                      child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _region == null
                                ? 'Drag over the part you want help with'
                                : _region!.isFullImage
                                    ? 'Using full image'
                                    : 'Drag inside to move. Drag corners to resize.',
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          )))),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Expanded(
                    child: Semantics(
                        selected: _region?.isFullImage ?? false,
                        child: TextButton.icon(
                          onPressed: _preview == null || _continuing
                              ? null
                              : () => setState(
                                  () => _region = FocusRegion.fullImage),
                          icon: Icon(
                              _region?.isFullImage == true
                                  ? Icons.check_circle_outline
                                  : Icons.image_outlined,
                              size: 18),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryLight),
                          label: const Text('Use full image',
                              style: TextStyle(fontSize: 14)),
                        ))),
                IconButton(
                    tooltip: 'Reset selection',
                    onPressed: _region == null || _continuing
                        ? null
                        : () => setState(() => _region = null),
                    icon: const Icon(Icons.restart_alt_rounded)),
              ]),
              SenseiPrimaryButton(
                  text: 'Continue',
                  height: 50,
                  onPressed: _region == null || _continuing ? null : _continue),
            ]),
          ),
        ])),
      );
}
