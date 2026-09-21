import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/exam_dojo_subject.dart';
import '../../../friends/data/models/user_model.dart';
import '../../../friends/data/repositories/friend_repository_impl.dart';
import '../../services/exam_dojo_logger.dart';
import '../controller/exam_dojo_controller.dart';

class ExamDojoSetupFlowScreen extends StatefulWidget {
  const ExamDojoSetupFlowScreen({super.key});

  @override
  State<ExamDojoSetupFlowScreen> createState() =>
      _ExamDojoSetupFlowScreenState();
}

class _ExamDojoSetupFlowScreenState extends State<ExamDojoSetupFlowScreen> {
  int _currentStep = 0;
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupDescriptionController =
      TextEditingController();
  final TextEditingController _newSubjectController = TextEditingController();
  final TextEditingController _newChapterController = TextEditingController();
  final List<_SubjectDraft> _subjects = [];
  String? _selectedSubjectId;
  bool _isSubmitting = false;
  late final Future<List<UserModel>> _friendsFuture;
  final Set<String> _selectedFriendIds = {};

  @override
  void initState() {
    super.initState();
    _friendsFuture = FriendRepositoryImpl().getFriends();
  }

  void _nextStep() {
    if (_currentStep < 5) {
      setState(() => _currentStep += 1);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  void _addSubject() {
    final name = _newSubjectController.text.trim();
    if (name.isEmpty) return;
    final subject = _SubjectDraft(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
    );
    setState(() {
      _subjects.add(subject);
      _selectedSubjectId ??= subject.id;
      _newSubjectController.clear();
    });
  }

  Future<void> _pickExamDate(_SubjectDraft subject) async {
    final initial =
        subject.examDate ?? DateTime.now().add(const Duration(days: 7));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date == null) return;
    setState(() {
      subject.examDate = date;
    });
  }

  void _addChapter() {
    if (_selectedSubjectId == null) {
      _showMessage('Select a subject first.');
      return;
    }
    final name = _newChapterController.text.trim();
    if (name.isEmpty) return;
    final subject = _subjects.firstWhere((s) => s.id == _selectedSubjectId);
    setState(() {
      subject.chapters.add(name);
      _newChapterController.clear();
    });
  }

  Future<void> _submitDojo() async {
    if (_isSubmitting) return;
    final controller = context.read<ExamDojoController>();
    final name = _groupNameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Please enter a group name.');
      return;
    }
    if (_subjects.isEmpty) {
      _showMessage('Add at least one subject.');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final subjects = _subjects.map((draft) => draft.toSubject()).toList();
      final description = _groupDescriptionController.text.trim();
      ExamDojoLogger.log(
        'ui.submitDojo',
        details: {
          'name': name,
          'descriptionLength': description.length,
          'memberCount': _selectedFriendIds.length,
          'subjectDrafts': subjects
              .map(
                (s) => {
                  'id': s.id,
                  'name': s.name,
                  'examDate': s.examDate.toIso8601String(),
                  'chapters': s.chapters,
                },
              )
              .toList(),
        },
      );
      await controller.createDojo(
        name: name,
        description: description.isEmpty ? null : description,
        subjects: subjects,
        memberIds: _selectedFriendIds.toList(),
      );
      final now = DateTime.now();
      final latestExam = subjects
          .map((subject) => subject.examDate)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      await controller.generateRoadmap(
        studyWindowStart: DateTime(now.year, now.month, now.day),
        studyWindowEnd: latestExam,
        weeklyLoadMinutes: 600,
      );
      await controller.ensureDailyBlocks(date: now);
      if (!mounted) return;
      Navigator.of(context).pop();
      ExamDojoLogger.log(
        'ui.submitDojo.completed',
        details: {'subjectCount': subjects.length},
      );
    } catch (e) {
      _showMessage('Unable to create dojo: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _groupDescriptionController.dispose();
    _newSubjectController.dispose();
    _newChapterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.orange[100],
        elevation: 0,
        title: const Text(
          'Exam Setup',
          style: TextStyle(
            fontFamily: 'DancingScript',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: SafeArea(
        child: Stepper(
          type: StepperType.vertical,
          currentStep: _currentStep,
          onStepContinue: _currentStep == 5 ? _submitDojo : _nextStep,
          onStepCancel: _previousStep,
          controlsBuilder: (context, details) {
            final isLast = _currentStep == 5;
            return Row(
              children: [
                FilledButton(
                  onPressed: _isSubmitting ? null : details.onStepContinue,
                  child: Text(isLast ? 'Go to Exam Dojo' : 'Continue'),
                ),
                const SizedBox(width: 12),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
              ],
            );
          },
          steps: [
            Step(
              title: const Text('Create group & add friends'),
              subtitle: Text('Step 1 of 6', style: theme.textTheme.bodySmall),
              isActive: _currentStep >= 0,
              content: _GroupSetupStep(
                theme: theme,
                nameController: _groupNameController,
                descriptionController: _groupDescriptionController,
                friendsFuture: _friendsFuture,
                selectedFriendIds: _selectedFriendIds,
                onToggleFriend: (friendId, selected) {
                  setState(() {
                    if (selected) {
                      _selectedFriendIds.add(friendId);
                    } else {
                      _selectedFriendIds.remove(friendId);
                    }
                  });
                },
              ),
            ),
            Step(
              title: const Text('Add subjects'),
              subtitle: Text('Step 2 of 6', style: theme.textTheme.bodySmall),
              isActive: _currentStep >= 1,
              content: _SubjectSetupStep(
                theme: theme,
                subjects: _subjects,
                controller: _newSubjectController,
                onAddSubject: _addSubject,
              ),
            ),
            Step(
              title: const Text('Assign exam dates'),
              subtitle: Text('Step 3 of 6', style: theme.textTheme.bodySmall),
              isActive: _currentStep >= 2,
              content: _ExamDatesStep(
                theme: theme,
                subjects: _subjects,
                onPickDate: _pickExamDate,
              ),
            ),
            Step(
              title: const Text('Add chapters/topics'),
              subtitle: Text('Step 4 of 6', style: theme.textTheme.bodySmall),
              isActive: _currentStep >= 3,
              content: _ChapterSetupStep(
                theme: theme,
                subjects: _subjects,
                selectedSubjectId: _selectedSubjectId,
                onSubjectSelected: (value) =>
                    setState(() => _selectedSubjectId = value),
                chapterController: _newChapterController,
                onAddChapter: _addChapter,
              ),
            ),
            Step(
              title: const Text('Review setup'),
              subtitle: Text('Step 5 of 6', style: theme.textTheme.bodySmall),
              isActive: _currentStep >= 4,
              content: _ReviewStep(theme: theme, subjects: _subjects),
            ),
            Step(
              title: const Text('Generate plan'),
              subtitle: Text('Step 6 of 6', style: theme.textTheme.bodySmall),
              isActive: _currentStep >= 5,
              content: _GeneratePlanStep(theme: theme),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupSetupStep extends StatelessWidget {
  const _GroupSetupStep({
    required this.theme,
    required this.nameController,
    required this.descriptionController,
    required this.friendsFuture,
    required this.selectedFriendIds,
    required this.onToggleFriend,
  });

  final ThemeData theme;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final Future<List<UserModel>> friendsFuture;
  final Set<String> selectedFriendIds;
  final void Function(String friendId, bool selected) onToggleFriend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Group details', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Group name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration:
                    const InputDecoration(labelText: 'Description (optional)'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Members', style: theme.textTheme.titleMedium),
                  Text(
                    '${selectedFriendIds.length} selected',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<UserModel>>(
                future: friendsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final friends = snapshot.data ?? [];
                  if (friends.isEmpty) {
                    return Text(
                      'No friends found. Add friends to invite them.',
                      style: theme.textTheme.bodyMedium,
                    );
                  }
                  return Column(
                    children: friends
                        .map(
                          (friend) => CheckboxListTile(
                            value: selectedFriendIds.contains(friend.id),
                            onChanged: (value) =>
                                onToggleFriend(friend.id, value ?? false),
                            title: Text(friend.name.isNotEmpty
                                ? friend.name
                                : 'Friend'),
                            subtitle: friend.email.isNotEmpty
                                ? Text(friend.email)
                                : null,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubjectSetupStep extends StatelessWidget {
  const _SubjectSetupStep({
    required this.theme,
    required this.subjects,
    required this.controller,
    required this.onAddSubject,
  });

  final ThemeData theme;
  final List<_SubjectDraft> subjects;
  final TextEditingController controller;
  final VoidCallback onAddSubject;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Subjects', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: subjects
                    .map((subject) => Chip(label: Text(subject.name)))
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Add a subject',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add_circle),
                    onPressed: onAddSubject,
                  ),
                ),
                onSubmitted: (_) => onAddSubject(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current list', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (subjects.isEmpty)
                Text(
                  'No subjects added yet.',
                  style: theme.textTheme.bodyMedium,
                )
              else
                ...subjects.map(
                  (subject) => _SimpleListTile(
                    title: subject.name,
                    subtitle: '${subject.chapters.length} chapters',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExamDatesStep extends StatelessWidget {
  const _ExamDatesStep({
    required this.theme,
    required this.subjects,
    required this.onPickDate,
  });

  final ThemeData theme;
  final List<_SubjectDraft> subjects;
  final void Function(_SubjectDraft subject) onPickDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assign exam dates', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              if (subjects.isEmpty)
                Text(
                  'Add subjects before assigning dates.',
                  style: theme.textTheme.bodyMedium,
                )
              else
                ...subjects.map(
                  (subject) => _DateRow(
                    subject: subject.name,
                    date: subject.examDate != null
                        ? _formatDate(subject.examDate!)
                        : 'Pick date',
                    onTap: () => onPickDate(subject),
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
              Text('Calendar', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(child: Text('Calendar picker placeholder')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChapterSetupStep extends StatelessWidget {
  const _ChapterSetupStep({
    required this.theme,
    required this.subjects,
    required this.selectedSubjectId,
    required this.onSubjectSelected,
    required this.chapterController,
    required this.onAddChapter,
  });

  final ThemeData theme;
  final List<_SubjectDraft> subjects;
  final String? selectedSubjectId;
  final ValueChanged<String?> onSubjectSelected;
  final TextEditingController chapterController;
  final VoidCallback onAddChapter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Selected subject', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedSubjectId,
                items: subjects
                    .map(
                      (subject) => DropdownMenuItem(
                        value: subject.id,
                        child: Text(subject.name),
                      ),
                    )
                    .toList(),
                onChanged: onSubjectSelected,
                hint: const Text('Select subject'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chapters & topics', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (subjects.isEmpty || selectedSubjectId == null)
                Text(
                  'Select a subject to add chapters.',
                  style: theme.textTheme.bodyMedium,
                )
              else
                ..._chaptersForSelected(subjects, selectedSubjectId!).map(
                  (chapter) => _SimpleListTile(
                    title: chapter,
                    subtitle: 'Topic list',
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: chapterController,
                decoration: InputDecoration(
                  labelText: 'Add a chapter',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add_circle),
                    onPressed: onAddChapter,
                  ),
                ),
                onSubmitted: (_) => onAddChapter(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<String> _chaptersForSelected(
    List<_SubjectDraft> subjects,
    String selectedId,
  ) {
    return subjects.firstWhere((subject) => subject.id == selectedId).chapters;
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.theme, required this.subjects});

  final ThemeData theme;
  final List<_SubjectDraft> subjects;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Group summary', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                subjects.isEmpty
                    ? 'No subjects yet'
                    : 'Subjects: ${subjects.map((s) => s.name).join(', ')}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Exam dates', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (subjects.isEmpty)
                Text('No exam dates yet', style: theme.textTheme.bodyMedium)
              else
                ...subjects.map(
                  (subject) => _DateRow(
                    subject: subject.name,
                    date: subject.examDate != null
                        ? _formatDate(subject.examDate!)
                        : 'Pick date',
                    onTap: null,
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
              Text('Chapters', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (subjects.isEmpty)
                Text('No chapters added yet', style: theme.textTheme.bodyMedium)
              else
                ...subjects.map(
                  (subject) => _SimpleListTile(
                    title: subject.name,
                    subtitle: '${subject.chapters.length} chapters',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GeneratePlanStep extends StatelessWidget {
  const _GeneratePlanStep({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Generating your shared roadmap',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'We will create a shared roadmap and personalize daily study blocks for each member.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: 0.7,
            minHeight: 6,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
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

class _SimpleListTile extends StatelessWidget {
  const _SimpleListTile({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.subject,
    required this.date,
    required this.onTap,
  });

  final String subject;
  final String date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(subject),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.calendar_today_rounded, size: 16),
            label: Text(date),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final label = months[(date.month - 1).clamp(0, 11)];
  return '$label ${date.day}, ${date.year}';
}

class _SubjectDraft {
  _SubjectDraft({
    required this.id,
    required this.name,
    this.examDate,
  });

  final String id;
  final String name;
  DateTime? examDate;
  final List<String> chapters = [];

  ExamDojoSubject toSubject() {
    return ExamDojoSubject(
      id: id,
      name: name,
      examDate: examDate ?? DateTime.now().add(const Duration(days: 7)),
      chapters: List<String>.from(chapters),
    );
  }
}
