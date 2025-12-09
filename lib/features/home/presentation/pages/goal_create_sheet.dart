import 'package:flutter/material.dart';
import '../../data/models/long_term_goal.dart';
import '../../data/models/milestone.dart';

class GoalCreateSheet extends StatefulWidget {
  const GoalCreateSheet({
    super.key,
    required this.onCreateGoal,
  });

  final Future<void> Function({
    required String title,
    String? description,
    GoalCategory category,
    DateTime? targetDate,
    int priority,
    List<Milestone> milestones,
  }) onCreateGoal;

  @override
  State<GoalCreateSheet> createState() => _GoalCreateSheetState();
}

class _GoalCreateSheetState extends State<GoalCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  GoalCategory _category = GoalCategory.exam;
  DateTime? _targetDate;
  int _priority = 1;
  final List<_MilestoneFormEntry> _milestones = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final entry in _milestones) {
      entry.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _targetDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final milestones = _milestones
          .where((entry) => entry.controller.text.trim().isNotEmpty)
          .map(
            (entry) => Milestone(
              id: '',
              goalId: '',
              userId: '',
              title: entry.controller.text.trim(),
              dueDate: entry.dueDate,
            ),
          )
          .toList();
      await widget.onCreateGoal(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _category,
        targetDate: _targetDate,
        priority: _priority,
        milestones: milestones,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _addMilestone() {
    setState(() {
      _milestones.add(_MilestoneFormEntry());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                'New Goal',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Goal title',
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter a title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Why is this important?',
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<GoalCategory>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: GoalCategory.values
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _category = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Target date'),
                subtitle: Text(
                  _targetDate != null
                      ? '${_targetDate!.month}/${_targetDate!.day}/${_targetDate!.year}'
                      : 'No target set',
                ),
                trailing: IconButton(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Priority'),
                  Expanded(
                    child: Slider(
                      value: _priority.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: '$_priority',
                      onChanged: (value) {
                        setState(() => _priority = value.round());
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Milestones',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_milestones.isEmpty)
                Text(
                  'Break this goal into smaller study blocks.',
                  style: theme.textTheme.bodyMedium,
                ),
              ..._milestones.map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: entry.controller,
                          decoration: const InputDecoration(
                            labelText: 'Milestone',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: entry.dueDate ?? now,
                            firstDate: now.subtract(const Duration(days: 365)),
                            lastDate: DateTime(now.year + 5),
                          );
                          if (picked != null) {
                            setState(() {
                              entry.dueDate = picked;
                            });
                          }
                        },
                        icon: const Icon(Icons.event),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _milestones.remove(entry);
                          });
                        },
                        icon: const Icon(Icons.clear),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _addMilestone,
                icon: const Icon(Icons.add),
                label: const Text('Add milestone'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create goal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MilestoneFormEntry {
  _MilestoneFormEntry() : controller = TextEditingController();
  final TextEditingController controller;
  DateTime? dueDate;
}
