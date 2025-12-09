import 'package:flutter/material.dart';

import '../../data/models/home_assignment.dart';
import '../../data/models/long_term_goal.dart';
import '../../data/models/study_block.dart';

class StudyBlockSheet extends StatefulWidget {
  const StudyBlockSheet({
    super.key,
    required this.goals,
    required this.assignments,
    required this.onSubmit,
    this.initialBlock,
  });

  final List<LongTermGoal> goals;
  final List<HomeAssignment> assignments;
  final StudyBlock? initialBlock;
  final Future<void> Function({
    required String title,
    required DateTime scheduledAt,
    required int durationMinutes,
    String? subject,
    String? goalId,
    String? assignmentId,
    bool reminderEnabled,
  }) onSubmit;

  @override
  State<StudyBlockSheet> createState() => _StudyBlockSheetState();
}

class _StudyBlockSheetState extends State<StudyBlockSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _subjectController;
  late final TextEditingController _durationController;
  late DateTime _scheduledAt;
  late int _durationMinutes;
  bool _reminderEnabled = false;
  String? _selectedGoalId;
  String? _selectedAssignmentId;
  bool _isSaving = false;

  static const _durationOptions = [25, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialBlock;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _subjectController = TextEditingController(text: initial?.subject ?? '');
    _scheduledAt = initial?.scheduledAt ?? DateTime.now().add(const Duration(hours: 1));
    _durationMinutes = initial?.durationMinutes ?? 25;
    _durationController =
        TextEditingController(text: _durationMinutes.toString());
    _reminderEnabled = initial?.reminderEnabled ?? false;
    _selectedGoalId = initial?.goalId;
    _selectedAssignmentId = initial?.assignmentId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _scheduledAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _scheduledAt.hour,
          _scheduledAt.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (picked != null) {
      setState(() {
        _scheduledAt = DateTime(
          _scheduledAt.year,
          _scheduledAt.month,
          _scheduledAt.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final parsedMinutes = int.tryParse(_durationController.text.trim());
    if (parsedMinutes == null || parsedMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid duration.')),
      );
      return;
    }
    _durationMinutes = parsedMinutes;
    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(
        title: _titleController.text.trim(),
        scheduledAt: _scheduledAt,
        durationMinutes: _durationMinutes,
        subject: _subjectController.text.trim().isEmpty ? null : _subjectController.text.trim(),
        goalId: _selectedGoalId,
        assignmentId: _selectedAssignmentId,
        reminderEnabled: _reminderEnabled,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save study block: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.initialBlock == null ? 'New Study Block' : 'Edit Study Block',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title *'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Title is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(labelText: 'Subject (optional)'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Duration',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Wrap(
                  spacing: 8,
                  children: _durationOptions
                      .map(
                        (minutes) => ChoiceChip(
                          label: Text('$minutes min'),
                          selected: _durationMinutes == minutes,
                          onSelected: (_) => setState(() {
                            _durationMinutes = minutes;
                            _durationController.text = minutes.toString();
                          }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Custom duration (minutes)',
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null && parsed > 0) {
                      setState(() => _durationMinutes = parsed);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.event),
                        label: Text(
                          '${_scheduledAt.month}/${_scheduledAt.day}/${_scheduledAt.year}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.schedule),
                        label: Text(TimeOfDay.fromDateTime(_scheduledAt).format(context)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  value: _selectedGoalId,
                  decoration: const InputDecoration(labelText: 'Link to goal'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('None')),
                    ...widget.goals.map(
                      (goal) => DropdownMenuItem<String?>(
                        value: goal.id,
                        child: Text(goal.title),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _selectedGoalId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: _selectedAssignmentId,
                  decoration: const InputDecoration(labelText: 'Link to assignment'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('None')),
                    ...widget.assignments.map(
                      (assignment) => DropdownMenuItem<String?>(
                        value: assignment.id,
                        child: Text(assignment.title),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _selectedAssignmentId = value),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _reminderEnabled,
                  onChanged: (value) => setState(() => _reminderEnabled = value),
                  title: const Text('Remind me before this block'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.initialBlock == null ? 'Create Block' : 'Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
