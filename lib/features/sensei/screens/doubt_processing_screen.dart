import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../common/widgets/sensei_primary_button.dart';
import '../models/sensei_help_request.dart';
import '../models/sensei_doubt_error.dart';
import 'doubt_result_screen.dart';
import '../services/sensei_doubt_api_service.dart';

class DoubtProcessingScreen extends StatefulWidget {
  final SenseiHelpRequest request;
  final DoubtApi Function()? createApi;
  final VoidCallback? onTryAnother;
  const DoubtProcessingScreen(
      {super.key, required this.request, this.createApi, this.onTryAnother});
  @override
  State<DoubtProcessingScreen> createState() => _DoubtProcessingScreenState();
}

class _DoubtProcessingScreenState extends State<DoubtProcessingScreen> {
  DoubtApi? _api;
  SenseiDoubtError? _error;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _submit();
  }

  @override
  void dispose() {
    _api?.close();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _api?.close();
      final api = _api = widget.createApi?.call() ?? SenseiDoubtApiService();
      final result = await api.submit(widget.request);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      navigator.pushReplacement(MaterialPageRoute<void>(
          builder: (_) => DoubtResultScreen(
              response: result,
              request: widget.request,
              onTryAnother: widget.onTryAnother ??
                  () => navigator.popUntil((route) => route.isFirst))));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is SenseiDoubtError
            ? error
            : const SenseiDoubtError(DoubtErrorCode.internalError);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            leading:
                BackButton(onPressed: () => Navigator.of(context).maybePop())),
        body: SafeArea(
            child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight:
                        (constraints.maxHeight - 48).clamp(0, double.infinity)),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                          child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      AppColors.primary.withValues(alpha: .15),
                                  boxShadow: [
                                    BoxShadow(
                                        color: AppColors.primary
                                            .withValues(alpha: .18),
                                        blurRadius: 32)
                                  ]),
                              child: Icon(
                                  _error == null
                                      ? Icons.auto_awesome_rounded
                                      : Icons.refresh_rounded,
                                  color: AppColors.primary,
                                  size: 36))),
                      const SizedBox(height: 28),
                      Semantics(
                          liveRegion: true,
                          child: Text(
                              _error?.message ??
                                  'Sensei is looking at your work…',
                              style: AppTypography.sectionTitle,
                              textAlign: TextAlign.center)),
                      const SizedBox(height: 16),
                      if (_error == null)
                        const Text('Looking at the part you selected…',
                            style: AppTypography.bodyMedium,
                            textAlign: TextAlign.center),
                      if (_error != null) ...[
                        SenseiPrimaryButton(
                            text: 'Retry',
                            onPressed: _loading ? null : _submit),
                        const SizedBox(height: 12),
                        TextButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            child: const Text('Back')),
                      ],
                    ]),
              )),
        )),
      );
}
