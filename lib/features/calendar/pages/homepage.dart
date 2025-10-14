import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/add_assignment.dart';

class AssignmentPage extends StatefulWidget {
  const AssignmentPage({Key? key}) : super(key: key);

  @override
  _AssignmentPageState createState() => _AssignmentPageState();
}

class _AssignmentPageState extends State<AssignmentPage> {
  late CalendarFormat _calendarFormat;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  final Map<DateTime, List<Map<String, dynamic>>> _events = {};
  final List<Map<String, dynamic>> _allAssignments = [];
  final List<Map<String, dynamic>> _selectedDayAssignments = [];
  late Stream<QuerySnapshot> _assignmentsStream;

  final Map<String, Color> subjectColors = {};

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
    _calendarFormat = CalendarFormat.month;
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    _loadSubjects();
    _loadAssignments();
  }

  void _loadAssignments() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _assignmentsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('assignments')
        .orderBy('deadline')
        .snapshots();

    _assignmentsStream.listen((snapshot) {
      if (mounted) {
        _updateAssignments(snapshot);
        // Automatically cleanup past assignments when loading
        _cleanupPastAssignments();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Load subjects and assign colors
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
          for (var doc in snapshot.docs) {
            final subject = doc['name'] as String? ?? '';
            if (subject.isNotEmpty && !subjectColors.containsKey(subject)) {
              subjectColors[subject] = _availableColors[
                  subjectColors.length % _availableColors.length];
            }
          }
        });
      }
    });
  }

  void _updateAssignments(QuerySnapshot snapshot) {
    if (!mounted) return;

    setState(() {
      _events.clear();
      _allAssignments.clear();

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

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y • h:mm a').format(date);
  }

  Color _getSubjectColor(String subject) {
    return subjectColors[subject] ?? Colors.grey;
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
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      print('Error cleaning up past assignments: $e');
    }
  }

  // Function to toggle assignment completion status
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
        elevation: 0, // Remove elevation from app bar
        title: const Padding(
          padding: EdgeInsets.only(bottom: 10), // Center the title
          child: Text(
            'StudySensei',
            style: TextStyle(
              fontFamily: 'DancingScript',
              fontSize: 40, // Slightly smaller font size
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
                  padding: const EdgeInsets.only(
                    right: 8,
                    top: 8,
                    bottom: 8,
                  ),
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
      elevation: 0, // Remove card elevation
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
        final subject = assignment['subject'] as String? ?? 'No Subject';
        final deadline = assignment['deadline'] as DateTime?;
        final isCompleted = assignment['completed'] as bool? ?? false;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: 2,
          color: isCompleted ? Colors.grey[100] : null,
          child: ListTile(
            title: Text(
              assignment['name'] ?? 'No Name',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? Colors.grey[600] : null,
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
                    color: isCompleted ? Colors.grey[500] : null,
                  ),
                ),
                if (deadline != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Due: ${_formatDate(deadline)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isCompleted ? Colors.grey[400] : Colors.grey,
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
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            leading: CircleAvatar(
              backgroundColor:
                  isCompleted ? Colors.grey[400] : _getSubjectColor(subject),
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : Text(
                      subject[0].toUpperCase(),
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
