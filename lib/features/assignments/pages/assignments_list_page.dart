import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AssignmentsListPage extends StatefulWidget {
  const AssignmentsListPage({Key? key}) : super(key: key);

  @override
  _AssignmentsListPageState createState() => _AssignmentsListPageState();
}

class _AssignmentsListPageState extends State<AssignmentsListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Stream<QuerySnapshot> _assignmentsStream;
  final Map<String, Color> _subjectColors = {};
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
    _loadAssignments();
  }

  void _loadAssignments() {
    final user = _auth.currentUser;
    if (user != null) {
      _assignmentsStream = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('assignments')
          .orderBy('deadline')
          .where('deadline', isGreaterThanOrEqualTo: DateTime.now())
          .snapshots();
    }
  }

  Color _getSubjectColor(String subject) {
    if (!_subjectColors.containsKey(subject)) {
      _subjectColors[subject] =
          _availableColors[_subjectColors.length % _availableColors.length];
    }
    return _subjectColors[subject]!;
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y • h:mm a').format(date);
  }

  Future<void> _toggleAssignmentCompletion(
    String docId,
    bool currentStatus,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final newStatus = !currentStatus;
    
    try {
      // Update the assignment status in Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('assignments')
          .doc(docId)
          .update({
            'isCompleted': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      // Find and update the corresponding calendar event
      final calendarEvents = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('calendar_events')
          .where('assignmentId', isEqualTo: docId)
          .get();
      
      if (calendarEvents.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in calendarEvents.docs) {
          batch.update(doc.reference, {
            'isCompleted': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error updating assignment and calendar event: $e');
      // Revert the UI if there's an error
      if (mounted) {
        setState(() {
          // The stream will update this automatically, but we force a rebuild
          // to ensure the checkbox state is correct
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Assignments',
          style: TextStyle(
            fontFamily: 'DancingScript',
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.orange[100],
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _assignmentsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading assignments: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final assignments = snapshot.data?.docs ?? [];

          if (assignments.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No upcoming assignments!\n\nAll caught up for now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: assignments.length,
            itemBuilder: (context, index) {
              final doc = assignments[index];
              final assignment = doc.data() as Map<String, dynamic>;
              final deadline = (assignment['deadline'] as Timestamp).toDate();
              final subject = assignment['subject'] ?? 'No Subject';
              final name = assignment['name'] ?? 'Untitled';
              final description = assignment['description'] ?? '';
              final isCompleted = assignment['isCompleted'] ?? false;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _getSubjectColor(subject).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        subject.isNotEmpty ? subject[0].toUpperCase() : 'A',
                        style: TextStyle(
                          color: _getSubjectColor(subject),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: isCompleted ? Colors.grey : null,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (description.isNotEmpty) ...{
                        Text(
                          description,
                          style: TextStyle(
                            color: isCompleted ? Colors.grey[600] : null,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 4),
                      },
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: isCompleted ? Colors.grey : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(deadline),
                            style: TextStyle(
                              color: isCompleted
                                  ? Colors.grey
                                  : Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Checkbox(
                    value: isCompleted,
                    onChanged: (value) {
                      if (value != null) {
                        _toggleAssignmentCompletion(doc.id, isCompleted);
                      }
                    },
                    activeColor: Colors.orange,
                  ),
                  onTap: () {
                    // TODO: Navigate to assignment details
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
