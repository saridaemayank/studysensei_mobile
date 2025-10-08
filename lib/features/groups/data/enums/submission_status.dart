enum SubmissionStatus {
  notSubmitted,
  submitted,
  late,
  graded,
  needsRevision,
}

extension SubmissionStatusExtension on SubmissionStatus {
  String get name {
    switch (this) {
      case SubmissionStatus.notSubmitted:
        return 'Not Submitted';
      case SubmissionStatus.submitted:
        return 'Submitted';
      case SubmissionStatus.late:
        return 'Submitted Late';
      case SubmissionStatus.graded:
        return 'Graded';
      case SubmissionStatus.needsRevision:
        return 'Needs Revision';
    }
  }
}
