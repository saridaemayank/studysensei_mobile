enum AssignmentStatus {
  notStarted,
  inProgress,
  completed,
  pastDue,
  graded,
}

extension AssignmentStatusExtension on AssignmentStatus {
  String get name {
    switch (this) {
      case AssignmentStatus.notStarted:
        return 'Not Started';
      case AssignmentStatus.inProgress:
        return 'In Progress';
      case AssignmentStatus.completed:
        return 'Completed';
      case AssignmentStatus.pastDue:
        return 'Past Due';
      case AssignmentStatus.graded:
        return 'Graded';
    }
  }
}
