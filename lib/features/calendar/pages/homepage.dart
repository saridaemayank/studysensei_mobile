import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:study_sensei/core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../services/add_assignment.dart';

class AssignmentPage extends StatefulWidget {
  const AssignmentPage({super.key});

  @override
  State<AssignmentPage> createState() => _AssignmentPageState();
}

class _AssignmentPageState extends State<AssignmentPage> {
  late CalendarFormat _calendarFormat;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  final Map<DateTime, List<Map<String, dynamic>>> _events = {};
  final List<Map<String, dynamic>> _allAssignments = [];
  final List<Map<String, dynamic>> _selectedDayAssignments = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _assignmentsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _subjectsSubscription;
  StreamSubscription<User?>? _authSubscription;
  bool _isLoadingAssignments = true;

  final Map<String, Color> subjectColors = {};

  // Predefined colors for subjects
  final List<Color> _availableColors = [
    AppColors.primary,
    AppColors.info,
    AppColors.primaryLight,
  ];

  @override
  void initState() {
    super.initState();
    _calendarFormat = CalendarFormat.month;
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    _loadSubjects();
    _loadAssignments();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user == null) {
        _assignmentsSubscription?.cancel();
        _subjectsSubscription?.cancel();
        setState(() {
          _events.clear();
          _allAssignments.clear();
          _selectedDayAssignments.clear();
          subjectColors.clear();
          _isLoadingAssignments = false;
        });
      } else {
        _loadAssignments();
        _loadSubjects();
      }
    });
  }

  void _loadAssignments() {
    _assignmentsSubscription?.cancel();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _events.clear();
          _allAssignments.clear();
          _selectedDayAssignments.clear();
          _isLoadingAssignments = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingAssignments = true;
    });

    _assignmentsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('assignments')
        .orderBy('deadline')
        .snapshots()
        .listen(
      (snapshot) {
        if (mounted) {
          _updateAssignments(snapshot);
          _cleanupPastAssignments();
          _isLoadingAssignments = false;
        }
      },
      onError: (error) {
        if (error is FirebaseException && error.code == 'permission-denied') {
          if (mounted) {
            setState(() {
              _isLoadingAssignments = false;
            });
          }
          return;
        }
        debugPrint('Assignment listener error: $error');
      },
    );
  }

  @override
  void dispose() {
    _assignmentsSubscription?.cancel();
    _subjectsSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  // Load subjects and assign colors
  void _loadSubjects() {
    _subjectsSubscription?.cancel();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          subjectColors.clear();
        });
      }
      return;
    }

    _subjectsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('subjects')
        .orderBy('name')
        .snapshots()
        .listen(
      (snapshot) {
        if (mounted) {
          setState(() {
            for (var doc in snapshot.docs) {
              final subject = doc['name'] as String? ?? '';
              if (subject.isNotEmpty && !subjectColors.containsKey(subject)) {
                subjectColors[subject] = _availableColors[
                    subjectColors.length % _availableColors.length];
              }
            }
          });
        }
      },
      onError: (error) {
        if (error is FirebaseException && error.code == 'permission-denied') {
          return;
        }
        debugPrint('Subject listener error: $error');
      },
    );
  }

  void _updateAssignments(QuerySnapshot snapshot) {
    if (!mounted) return;

    setState(() {
      _events.clear();
      _allAssignments.clear();
      _isLoadingAssignments = false;

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          if (data['deadline'] == null) continue;

          final deadline = (data['deadline'] as Timestamp).toDate();
          final date = DateTime(deadline.year, deadline.month, deadline.day);

          final assignment = {
            'id': doc.id,
            ...data,
            'deadline': deadline,
            'completed': data['completed'] ?? false,
          };

          _allAssignments.add(assignment);
          _events[date] = [..._events[date] ?? [], assignment];
        } catch (e) {
          debugPrint('Assignment update unavailable.');
        }
      }

      _updateSelectedDayAssignments();
    });
  }

  void _updateSelectedDayAssignments() {
    _selectedDayAssignments.clear();
    _selectedDayAssignments.addAll(
      _allAssignments.where((assignment) {
        if (assignment['deadline'] == null) return false;
        return isSameDay(assignment['deadline'], _selectedDay);
      }),
    );
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _events[date] ?? [];
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y • h:mm a').format(date);
  }

  Color _getSubjectColor(String subject) {
    return subjectColors[subject] ?? AppColors.textSecondary;
  }

  // Function to check and delete past assignments
  Future<void> _cleanupPastAssignments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      final assignmentsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('assignments');

      // Get all assignments
      final snapshot = await assignmentsRef.get();
      final List<String> assignmentsToDelete = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final deadline = data['deadline'] as Timestamp?;
        final isCompleted = data['completed'] as bool? ?? false;

        if (deadline != null) {
          final deadlineDate = deadline.toDate();
          // Only delete completed assignments that are past due (more than 1 day old)
          // Keep incomplete assignments even if they're past due
          if (isCompleted &&
              deadlineDate.isBefore(now.subtract(const Duration(days: 1)))) {
            assignmentsToDelete.add(doc.id);
          }
        }
      }

      // Delete expired assignments
      if (assignmentsToDelete.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();

        for (String assignmentId in assignmentsToDelete) {
          batch.delete(assignmentsRef.doc(assignmentId));
        }

        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cleaned up ${assignmentsToDelete.length} completed assignment${assignmentsToDelete.length > 1 ? 's' : ''} past due',
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.info,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Assignment update unavailable.');
    }
  }

  // Function to toggle assignment completion status
  // Retained legacy handler; this presentation pass does not add actions.
  // ignore: unused_element
  Future<void> _toggleAssignmentCompletion(
    Map<String, dynamic> assignment,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final assignmentId = assignment['id'] as String;
      final currentStatus = assignment['completed'] as bool? ?? false;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('assignments')
          .doc(assignmentId)
          .update({'completed': !currentStatus});

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !currentStatus
                  ? 'Assignment marked as completed!'
                  : 'Assignment marked as incomplete!',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor:
                !currentStatus ? AppColors.success : AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error updating assignment status'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Assignments',
          style: TextStyle(
            fontFamily: 'Headings',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Builder(
        builder: (context) {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            return const Center(
              child: Text('Sign in to view your assignments.'),
            );
          }
          if (_isLoadingAssignments) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildBody();
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddAssignmentPage()),
          );

          if (result == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Assignment added successfully!'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              SizedBox(
                width: constraints.maxWidth * 0.5,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      _buildCalendar(),
                      const SizedBox(height: 8),
                      _buildAssignmentsHeader(),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                  child: _buildAssignmentList(),
                ),
              ),
            ],
          );
        },
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildCalendar()),
        SliverToBoxAdapter(child: _buildAssignmentsHeader()),
        SliverToBoxAdapter(child: _buildAssignmentList(shrinkWrap: true)),
        const SliverToBoxAdapter(child: SizedBox(height: 88)),
      ],
    );
  }

  Widget _buildAssignmentsHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Assignments',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Card(
      elevation: 0, // Remove card elevation
      margin: const EdgeInsets.all(8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borderSubtle, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TableCalendar(
          firstDay: DateTime.utc(2010, 10, 16),
          lastDay: DateTime.utc(2030, 3, 14),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            if (!isSameDay(_selectedDay, selectedDay)) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _updateSelectedDayAssignments();
              });
            }
          },
          onFormatChanged: (format) {
            if (_calendarFormat != format) {
              setState(() {
                _calendarFormat = format;
              });
            }
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          eventLoader: _getEventsForDay,
          calendarStyle: CalendarStyle(
            markerDecoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            todayDecoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: true,
            titleCentered: true,
          ),
        ),
      ),
    );
  }

  Widget _buildAssignmentList({bool shrinkWrap = false}) {
    if (_selectedDayAssignments.isEmpty) {
      return const Padding(
          padding: EdgeInsets.all(24),
          child: Text('No assignments for this day.',
              textAlign: TextAlign.center));
    }

    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      itemCount: _selectedDayAssignments.length,
      itemBuilder: (context, index) {
        final assignment = _selectedDayAssignments[index];
        final subject = assignment['subject'] as String? ?? 'No Subject';
        final deadline = assignment['deadline'] as DateTime?;
        final isCompleted = assignment['completed'] as bool? ?? false;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: 0,
          color: isCompleted ? AppColors.surfaceElevated : null,
          child: ListTile(
            title: Text(
              assignment['name'] ?? 'No Name',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? AppColors.textSecondary : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Subject: $subject',
                  style: TextStyle(
                    fontSize: 14,
                    color: isCompleted ? AppColors.textSecondary : null,
                  ),
                ),
                if (deadline != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Due: ${_formatDate(deadline)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isCompleted
                          ? AppColors.textSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
                if (isCompleted) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            leading: CircleAvatar(
              backgroundColor: isCompleted
                  ? AppColors.textSecondary
                  : _getSubjectColor(subject),
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : Text(
                      subject.isEmpty ? 'A' : subject[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            onTap: () {
              // You can add assignment details view here if needed
            },
          ),
        );
      },
    );
  }
}
