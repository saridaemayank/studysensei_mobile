import 'package:flutter/material.dart';
import 'package:study_sensei/features/groups/data/models/group_assignment_model.dart';
import 'package:study_sensei/features/groups/data/enums/assignment_status.dart';

class AddAssignmentDialog extends StatefulWidget {
  final String groupId;
  final String currentUserId;
  final List<String> memberIds;
  final Function(GroupAssignment) onAssignmentAdded;

  const AddAssignmentDialog({
    Key? key,
    required this.groupId,
    required this.currentUserId,
    required this.memberIds,
    required this.onAssignmentAdded,
  }) : super(key: key);

  @override
  _AddAssignmentDialogState createState() => _AddAssignmentDialogState();
}

class _AddAssignmentDialogState extends State<AddAssignmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _dueDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final assignment = GroupAssignment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        groupId: widget.groupId,
        title: _titleController.text,
        description: _descriptionController.text,
        dueDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
        createdAt: DateTime.now(),
        createdBy: widget.currentUserId,
        status: AssignmentStatus.notStarted,
        assignedTo: widget.memberIds, // Assign to all group members
        submissions: [],
        userCompletion: Map.fromIterable(
          widget.memberIds,
          key: (id) => id,
          value: (_) => false,
        ),
      );

      widget.onAssignmentAdded(assignment);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create assignment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Assignment'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  _dueDate == null
                      ? 'No due date'
                      : 'Due: ${_dueDate!.toString().split(' ')[0]}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDueDate(context),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add Assignment'),
        ),
      ],
    );
  }
}
