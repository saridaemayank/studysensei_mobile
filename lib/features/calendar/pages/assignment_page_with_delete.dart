import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../services/add_assignment.dart';
import '../widgets/swipeable_assignment_item.dart';

class AssignmentPageWithDelete extends StatefulWidget {
  const AssignmentPageWithDelete({Key? key}) : super(key: key);

  @override
  _AssignmentPageWithDeleteState createState() =>
      _AssignmentPageWithDeleteState();
}

class _AssignmentPageWithDeleteState extends State<AssignmentPageWithDelete> {
  late CalendarFormat _calendarFormat;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  final Map<DateTime, List<Map<String, dynamic>>> _events = {};
  final List<Map<String, dynamic>> _allAssignments = [];
  final List<Map<String, dynamic>> _selectedDayAssignments = [];
  bool _isDeleting = false;
  Stream<QuerySnapshot> _assignmentsStream = const Stream<QuerySnapshot>.empty();
  StreamSubscription<QuerySnapshot>? _assignmentsSubscription;
  final Map<String, ScrollController> _scrollControllers = {};
  final Map<String, GlobalKey> _itemKeys = {};
  final Map<String, Color> subjectColors = {};
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
    _calendarFormat = CalendarFormat.month;
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    
    // Initialize the assignments stream
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _assignmentsStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('assignments')
          .orderBy('deadline')
          .snapshots();
          
      _assignmentsSubscription = _assignmentsStream.listen((snapshot) {
        if (mounted) {
          _updateAssignments(snapshot);
        }
      });
    }
  }

  @override
  void dispose() {
    _assignmentsSubscription?.cancel();
    for (var controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Function to delete an assignment
  Future<void> _deleteAssignment(String assignmentId) async {
    if (_isDeleting) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('assignments')
          .doc(assignmentId)
          .delete();

      // Clean up controllers and keys
      _scrollControllers.remove(assignmentId)?.dispose();
      _itemKeys.remove(assignmentId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment deleted successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error deleting assignment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete assignment'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  void _updateAssignments(QuerySnapshot snapshot) {
    if (!mounted) return;

    setState(() {
      _allAssignments.clear();
      _events.clear();
      subjectColors.clear();

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
          print('Error processing assignment ${doc.id}: $e');
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

  Color _getSubjectColor(String subject) {
    // Use the subject's color or assign a new one if it doesn't exist
    if (!subjectColors.containsKey(subject)) {
      subjectColors[subject] = _availableColors[subjectColors.length % _availableColors.length];
    }
    return subjectColors[subject] ?? Colors.grey;
  }

  Future<void> _cleanupPastAssignments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      final assignmentsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('assignments');

      final snapshot = await assignmentsRef.get();
      final List<String> assignmentsToDelete = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final deadline = data['deadline'] as Timestamp?;
        final isCompleted = data['completed'] as bool? ?? false;

        if (deadline != null) {
          final deadlineDate = deadline.toDate();
          if (isCompleted &&
              deadlineDate.isBefore(now.subtract(const Duration(days: 1)))) {
            assignmentsToDelete.add(doc.id);
          }
        }
      }

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
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      print('Error cleaning up past assignments: $e');
    }
  }

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !currentStatus
                  ? 'Assignment marked as completed!'
                  : 'Assignment marked as incomplete!',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: !currentStatus ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error updating assignment completion: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error updating assignment status'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
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
        backgroundColor: Colors.orange[100],
        elevation: 0,
        title: const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'StudySensei',
            style: TextStyle(
              fontFamily: 'DancingScript',
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _assignmentsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading assignments'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return _buildBody();
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
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

    return Column(
      children: [
        _buildCalendar(),
        const SizedBox(height: 8),
        _buildAssignmentsHeader(),
        const SizedBox(height: 8),
        Expanded(child: _buildAssignmentList()),
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
      elevation: 0,
      margin: const EdgeInsets.all(8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
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
              color: Colors.orange[100],
              shape: BoxShape.circle,
            ),
            todayDecoration: const BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Colors.orange[300],
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

  Widget _buildAssignmentList() {
    if (_selectedDayAssignments.isEmpty) {
      return const Center(child: Text('No assignments for selected day'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      itemCount: _selectedDayAssignments.length,
      itemBuilder: (context, index) {
        final assignment = _selectedDayAssignments[index];
        final assignmentId = assignment['id'] as String;
        final subject = assignment['subject'] as String? ?? 'No Subject';
        final deadline = assignment['deadline'] as DateTime?;
        final isCompleted = assignment['completed'] as bool? ?? false;
        final name = assignment['name'] as String? ?? 'No Name';

        // Ensure we have a controller and key for this assignment
        if (!_scrollControllers.containsKey(assignmentId)) {
          _scrollControllers[assignmentId] = ScrollController();
          _itemKeys[assignmentId] = GlobalKey();
        }

        return SwipeableAssignmentItem(
          id: assignmentId,
          title: name,
          subject: subject,
          deadline: deadline,
          isCompleted: isCompleted,
          subjectColor: _getSubjectColor(subject),
          onDelete: () => _deleteAssignment(assignmentId),
          scrollController: _scrollControllers[assignmentId]!,
          containerKey: _itemKeys[assignmentId]!,
        );
      },
    );
  }
}
