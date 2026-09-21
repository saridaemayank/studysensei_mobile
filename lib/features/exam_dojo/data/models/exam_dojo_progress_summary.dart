class ExamDojoSubjectProgressStat {
  const ExamDojoSubjectProgressStat({
    required this.subjectId,
    required this.subjectName,
    required this.completedBlocks,
    required this.totalBlocks,
  });

  final String? subjectId;
  final String subjectName;
  final int completedBlocks;
  final int totalBlocks;

  double get ratio {
    if (totalBlocks <= 0) return 0;
    final value = completedBlocks / totalBlocks;
    if (value.isNaN) return 0;
    return value.clamp(0, 1);
  }
}

class ExamDojoProgressSummary {
  const ExamDojoProgressSummary({
    required this.subjects,
  });

  final List<ExamDojoSubjectProgressStat> subjects;

  int get completedBlocks =>
      subjects.fold(0, (sum, stat) => sum + stat.completedBlocks);

  int get totalBlocks =>
      subjects.fold(0, (sum, stat) => sum + stat.totalBlocks);

  double get overallRatio {
    if (totalBlocks <= 0) return 0;
    final value = completedBlocks / totalBlocks;
    if (value.isNaN) return 0;
    return value.clamp(0, 1);
  }
}
