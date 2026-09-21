import 'package:flutter/material.dart';

class ExamDojoEmptyStateScreen extends StatelessWidget {
  const ExamDojoEmptyStateScreen({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.orange[100],
        elevation: 0,
        title: const Text(
          'Exam Dojo',
          style: TextStyle(
            fontFamily: 'DancingScript',
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.groups_rounded,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Create your Exam Dojo',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Create one group to share subjects, exam dates, and chapters. Everyone gets a shared roadmap and their own daily study blocks.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onStart,
                  child: const Text('Start Exam Dojo'),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Learn how it works'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
