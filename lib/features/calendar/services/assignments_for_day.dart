import 'package:flutter/material.dart';

class AssignmentsForDayPage extends StatelessWidget {
  final DateTime selectedDay;
  final List<Map<String, dynamic>> assignments;

  AssignmentsForDayPage({required this.selectedDay, required this.assignments});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Assignments for ${selectedDay.toLocal()}'),
      ),
      body: ListView.builder(
        itemCount: assignments.length,
        itemBuilder: (context, index) {
          final assignment = assignments[index];
          return ListTile(
            title: Text(assignment['name']),
            subtitle: Text(assignment['subject']),
            trailing: Text(assignment['deadline']),
          );
        },
      ),
    );
  }
}
