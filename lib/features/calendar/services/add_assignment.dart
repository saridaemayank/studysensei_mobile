import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../home/data/models/long_term_goal.dart';
import '../../home/data/models/milestone.dart';
import 'firebase_service.dart';

class AddAssignmentPage extends StatefulWidget {
  @override
  _AddAssignmentPageState createState() => _AddAssignmentPageState();
}

class _AddAssignmentPageState extends State<AddAssignmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  // Removed the hardcoded default subject
  DateTime _deadline = DateTime.now();

  final List<String> subjects = [];
  final Map<String, Color> subjectColors = {};
  final List<LongTermGoal> _goals = [];
  final Map<String, List<Milestone>> _goalMilestones = {};
  String? _selectedSubject;
  String? _selectedGoalId;
  String? _selectedMilestoneId;
  bool _linkToMilestone = false;
  bool _isSaving = false;

  // Predefined colors for subjects
  final List<Color> _availableColors = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
    Colors.indigo,
  ];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
    _loadGoalsAndMilestones();
  }

  void _loadSubjects() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('subjects')
        .orderBy('name')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          subjects.clear();
          for (var doc in snapshot.docs) {
            final subject = doc['name'] as String? ?? '';
            if (subject.isNotEmpty) {
              subjects.add(subject);
              // Assign a color if not already assigned
              if (!subjectColors.containsKey(subject)) {
                subjectColors[subject] =
                    _availableColors[subjects.length % _availableColors.length];
              }
            }
          }

          // Set the first subject as selected if none is selected
          if (_selectedSubject == null && subjects.isNotEmpty) {
            _selectedSubject = subjects.first;
          }
        });
      }
    });
  }

  Future<void> _loadGoalsAndMilestones() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final goalSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('longTermGoals')
          .orderBy('createdAt', descending: true)
          .get();
      final goals = goalSnapshot.docs.map(LongTermGoal.fromDoc).toList();
      final Map<String, List<Milestone>> milestoneMap = {};
      for (final goalDoc in goalSnapshot.docs) {
        final milestonesSnapshot =
            await goalDoc.reference.collection('milestones').get();
        milestoneMap[goalDoc.id] =
            milestonesSnapshot.docs.map(Milestone.fromDoc).toList();
      }
      if (mounted) {
        setState(() {
          _goals
            ..clear()
            ..addAll(goals);
          _goalMilestones
            ..clear()
            ..addAll(milestoneMap);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load goals: $e')),
        );
      }
    }
  }

  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate() || _selectedSubject == null) {
      return;
    }
    if (_linkToMilestone &&
        (_selectedGoalId == null || _selectedMilestoneId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a goal and milestone.')),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      final assignmentId = await FirebaseService.addAssignment(
        name: _nameController.text.trim(),
        subject: _selectedSubject!,
        deadline: _deadline,
        goalId: _linkToMilestone ? _selectedGoalId : null,
        milestoneId: _linkToMilestone ? _selectedMilestoneId : null,
      );

      if (_linkToMilestone &&
          _selectedGoalId != null &&
          _selectedMilestoneId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('longTermGoals')
            .doc(_selectedGoalId)
            .collection('milestones')
            .doc(_selectedMilestoneId)
            .update({
          'linkedAssignmentIds': FieldValue.arrayUnion([assignmentId]),
        });
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving assignment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _deadline) {
      setState(() {
        _deadline = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _deadline.hour,
          _deadline.minute,
        );
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline),
    );
    if (picked != null) {
      setState(() {
        _deadline = DateTime(
          _deadline.year,
          _deadline.month,
          _deadline.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Assignment')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Assignment Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  subjects.isEmpty
                      ? const Text('No subjects found. Please add subjects first.')
                      : DropdownButtonFormField<String>(
                          value: _selectedSubject,
                          decoration: const InputDecoration(
                            labelText: 'Subject',
                            border: OutlineInputBorder(),
                          ),
                          items: subjects.map((subject) {
                            return DropdownMenuItem(
                              value: subject,
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: subjectColors[subject] ?? Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(subject),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedSubject = value;
                              });
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a subject';
                            }
                            return null;
                          },
                        ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              DateFormat('MMM d, yyyy').format(_deadline),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(context),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Time',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(DateFormat('h:mm a').format(_deadline)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Link to a milestone'),
                    value: _linkToMilestone,
                    onChanged: (value) {
                      setState(() {
                        _linkToMilestone = value;
                        if (!value) {
                          _selectedGoalId = null;
                          _selectedMilestoneId = null;
                        }
                      });
                    },
                  ),
                  if (_linkToMilestone) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedGoalId,
                      decoration: const InputDecoration(
                        labelText: 'Goal',
                        border: OutlineInputBorder(),
                      ),
                      items: _goals
                          .map(
                            (goal) => DropdownMenuItem(
                              value: goal.id,
                              child: Text(goal.title),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedGoalId = value;
                          _selectedMilestoneId = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedMilestoneId,
                      decoration: const InputDecoration(
                        labelText: 'Milestone',
                        border: OutlineInputBorder(),
                      ),
                      items: (_goalMilestones[_selectedGoalId] ?? [])
                          .map(
                            (milestone) => DropdownMenuItem(
                              value: milestone.id,
                              child: Text(milestone.title),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedMilestoneId = value;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveAssignment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Save Assignment',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
