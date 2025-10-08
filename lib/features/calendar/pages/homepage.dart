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
  int _currentIndex = 0;
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
                  subjectColors[subject] =
                      _availableColors[subjectColors.length %
                          _availableColors.length];
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

          final assignment = {'id': doc.id, ...data, 'deadline': deadline};

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
    return Column(
      children: [
        _buildCalendar(),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Assignments',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildAssignmentList()),
      ],
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

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: 2,
          child: ListTile(
            title: Text(
              assignment['name'] ?? 'No Name',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Subject: $subject', style: const TextStyle(fontSize: 14)),
                if (deadline != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Due: ${_formatDate(deadline)}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ],
            ),
            leading: CircleAvatar(
              backgroundColor: _getSubjectColor(subject),
              child: Text(
                subject[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onTap: () {
              // Handle assignment tap
            },
          ),
        );
      },
    );
  }
}
