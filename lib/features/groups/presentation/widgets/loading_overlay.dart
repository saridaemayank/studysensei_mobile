import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? loadingMessage;
  final Color overlayColor;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.loadingMessage,
    this.overlayColor = Colors.black54,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        child,
        
        // Loading overlay
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: overlayColor,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    if (loadingMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        loadingMessage!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

extension LoadingOverlayExtension on BuildContext {
  void showLoadingOverlay([String? message]) {
    showDialog(
      context: this,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void hideLoadingOverlay() {
    Navigator.of(this, rootNavigator: true).pop();
  }
}
