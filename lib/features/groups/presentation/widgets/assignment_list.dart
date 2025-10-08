import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_sensei/features/groups/data/enums/assignment_status.dart';
import 'package:study_sensei/features/groups/data/models/group_assignment_model.dart';
import 'package:study_sensei/features/groups/presentation/bloc/assignment/assignment_bloc.dart';

class AssignmentList extends StatelessWidget {
  final String groupId;
  final bool isAdmin;
  final List<GroupAssignment> assignments;
  final String currentUserId;

  const AssignmentList({
    super.key,
    required this.groupId,
    required this.isAdmin,
    required this.assignments,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    // Using assignments passed from parent

    if (assignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No assignments yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (isAdmin) ...[
              const SizedBox(height: 8),
              const Text('Tap + to create a new assignment'),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: assignments.length,
      itemBuilder: (context, index) {
        final assignment = assignments[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          child: ListTile(
            title: Row(
              children: [
                // Completion Checkbox
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Builder(
                  builder: (context) {
                    final isCompleted = assignment.isCompletedByUser(currentUserId);
                    print('Rendering checkbox for assignment ${assignment.id} - isCompleted: $isCompleted');
                    return Checkbox(
                      value: isCompleted,
                      onChanged: (value) {
                        print('Checkbox toggled - new value: $value');
                        if (value != null) {
                          context.read<AssignmentBloc>().add(
                            CompleteAssignment(
                              assignmentId: assignment.id,
                              groupId: groupId,
                              userId: currentUserId,
                              isCompleted: value,
                            ),
                          );
                        }
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                    );
                  },
                ),
                ),
                // Assignment Title with Strike-through if completed
                Expanded(
                  child: Text(
                    assignment.title,
                    style: TextStyle(
                      fontSize: 16,
                      decoration: assignment.isCompletedByUser(currentUserId)
                          ? TextDecoration.lineThrough
                          : null,
                      color: assignment.isCompletedByUser(currentUserId)
                          ? Colors.grey
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(left: 44.0, top: 4.0, bottom: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress indicator
                  _buildProgressIndicator(context, assignment),
                  const SizedBox(height: 4.0),
                Text(
                  assignment.status == AssignmentStatus.completed && assignment.updatedAt != null
                      ? 'Completed by ${_formatDate(assignment.updatedAt!)}'
                      : 'Due: ${_formatDate(assignment.dueDate)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: assignment.status == AssignmentStatus.completed 
                        ? Colors.green 
                        : null,
                    fontStyle: assignment.status == AssignmentStatus.completed 
                        ? FontStyle.italic 
                        : null,
                  ),
                ),
                ],
              ),
            ),
            // Always show status chip, but with different styling for completed status
            trailing: _buildStatusChip(context, assignment),
            onTap: () {
              // TODO: Navigate to assignment detail
            },
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(BuildContext context, GroupAssignment assignment) {
    final isCompleted = assignment.status == AssignmentStatus.completed;
    final color = _getStatusColor(assignment.status, context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green.withOpacity(0.1) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.0),
        border: isCompleted ? Border.all(color: Colors.green) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCompleted)
            const Icon(Icons.check_circle, size: 14, color: Colors.green,),
          if (isCompleted) const SizedBox(width: 4),
          Text(
            assignment.status.name,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isCompleted ? Colors.green : color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(AssignmentStatus status, BuildContext context) {
    final theme = Theme.of(context);
    switch (status) {
      case AssignmentStatus.notStarted:
        return theme.colorScheme.primary;
      case AssignmentStatus.inProgress:
        return theme.colorScheme.primary;
      case AssignmentStatus.completed:
        return Colors.green;
      case AssignmentStatus.pastDue:
        return theme.colorScheme.error;
      case AssignmentStatus.graded:
        return Colors.green;
    }
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(DateTime(now.year, now.month, now.day));
    
    if (difference.inDays == 0) {
      return 'Today, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Tomorrow, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == -1) {
      return 'Yesterday, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${_getMonth(date.month)} ${date.day}, ${date.year}';
    }
  }


  String _getMonth(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  Widget _buildProgressIndicator(BuildContext context, GroupAssignment assignment) {
    final completedCount = assignment.userCompletion.values
        .where((isCompleted) => isCompleted)
        .length;
    final totalAssigned = assignment.assignedTo.length;
    final allCompleted = completedCount == totalAssigned && totalAssigned > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (totalAssigned > 0) ...[
          LinearProgressIndicator(
            value: totalAssigned > 0 ? completedCount / totalAssigned : 0,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              allCompleted 
                ? Colors.green 
                : Theme.of(context).colorScheme.primary,
            ),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 4),
          Text(
            allCompleted
                ? 'Completed by all members ✅'
                : '$completedCount/$totalAssigned members completed',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: allCompleted ? Colors.green : null,
                  fontWeight: allCompleted ? FontWeight.bold : null,
                ),
          ),
        ] else
          Text(
            'No members assigned',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
          ),
      ],
    );
  }
}
