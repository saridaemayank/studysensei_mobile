import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/exam_dojo_controller.dart';

class ExamDojoSubjectSetupScreen extends StatelessWidget {
  const ExamDojoSubjectSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.orange[100],
        elevation: 0,
        title: const Text(
          'Subject Setup',
          style: TextStyle(
            fontFamily: 'DancingScript',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: SafeArea(
        child: Consumer<ExamDojoController>(
          builder: (context, controller, _) {
            final dojo = controller.dojo;
            if (controller.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (dojo == null) {
              return Center(
                child: Text(
                  'Create an Exam Dojo to edit subjects.',
                  style: theme.textTheme.bodyMedium,
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Manage subjects in your shared roadmap.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Subjects', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      if (dojo.subjects.isEmpty)
                        Text(
                          'No subjects added yet.',
                          style: theme.textTheme.bodyMedium,
                        )
                      else
                        ...dojo.subjects.map(
                          (subject) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(subject.name),
                            subtitle: Text(
                              '${subject.chapters.length} chapters',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add new subject',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Subject name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Exam date',
                          suffixIcon: Icon(Icons.calendar_today_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Estimated effort (optional)',
                          hintText: 'e.g., 20 hours',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: const Text('Save Subject'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

// Editing chapters will be wired once the backend is ready.
