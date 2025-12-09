import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/home_assignment.dart';
import '../../data/models/long_term_goal.dart';
import '../../data/models/milestone.dart';
import '../../data/models/study_block.dart';
import '../../data/models/study_session.dart';
import '../../data/repositories/home_repository.dart';

class WeeklySummary {
  final Duration totalStudyTime;
  final int completedMilestones;
  final int totalMilestones;
  final int streakDays;

  const WeeklySummary({
    required this.totalStudyTime,
    required this.completedMilestones,
    required this.totalMilestones,
    required this.streakDays,
  });
}

class HomeState {
  final List<LongTermGoal> goals;
  final List<Milestone> milestones;
  final List<HomeAssignment> assignments;
  final List<StudyBlock> studyBlocks;
  final List<StudySession> studySessions;
  final DateTime selectedDay;
  final DateTime weekStart;
  final bool isLoading;
  final String? errorMessage;

  const HomeState({
    required this.goals,
    required this.milestones,
    required this.assignments,
    required this.studyBlocks,
    required this.studySessions,
    required this.selectedDay,
    required this.weekStart,
    required this.isLoading,
    this.errorMessage,
  });

  factory HomeState.initial() {
    final now = DateTime.now();
    final startOfWeek = _startOfWeek(now);
    final selectedDay = DateTime(now.year, now.month, now.day);
    return HomeState(
      goals: const [],
      milestones: const [],
      assignments: const [],
      studyBlocks: const [],
      studySessions: const [],
      selectedDay: selectedDay,
      weekStart: startOfWeek,
      isLoading: true,
    );
  }

  HomeState copyWith({
    List<LongTermGoal>? goals,
    List<Milestone>? milestones,
    List<HomeAssignment>? assignments,
    List<StudyBlock>? studyBlocks,
    List<StudySession>? studySessions,
    DateTime? selectedDay,
    DateTime? weekStart,
    bool? isLoading,
    String? errorMessage,
  }) {
    return HomeState(
      goals: goals ?? this.goals,
      milestones: milestones ?? this.milestones,
      assignments: assignments ?? this.assignments,
      studyBlocks: studyBlocks ?? this.studyBlocks,
      studySessions: studySessions ?? this.studySessions,
      selectedDay: selectedDay ?? this.selectedDay,
      weekStart: weekStart ?? this.weekStart,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required this.repository,
    required this.userId,
  }) {
    _init();
  }

  final HomeRepository repository;
  final String userId;

  HomeState _state = HomeState.initial();
  HomeState get state => _state;

  StreamSubscription<List<LongTermGoal>>? _goalsSub;
  StreamSubscription<List<Milestone>>? _milestonesSub;
  StreamSubscription<List<HomeAssignment>>? _assignmentsSub;
  StreamSubscription<List<StudyBlock>>? _studyBlocksSub;
  StreamSubscription<List<StudySession>>? _studySessionsSub;

  void _init() {
    _goalsSub = repository.watchGoals(userId).listen(
      (goals) {
        _updateState(goals: goals, isLoading: false, errorMessage: null);
      },
      onError: (error) => _updateState(errorMessage: error.toString()),
    );
    _milestonesSub = repository.watchMilestones(userId).listen(
      (milestones) {
        _updateState(milestones: milestones, isLoading: false, errorMessage: null);
      },
      onError: (error) => _updateState(errorMessage: error.toString()),
    );
    _assignmentsSub = repository.watchAssignments(userId).listen(
      (assignments) {
        _updateState(assignments: assignments, isLoading: false, errorMessage: null);
      },
      onError: (error) => _updateState(errorMessage: error.toString()),
    );
    _studyBlocksSub = repository.watchStudyBlocks(userId).listen(
      (blocks) =>
          _updateState(studyBlocks: blocks, isLoading: false, errorMessage: null),
      onError: (error) => _updateState(errorMessage: error.toString()),
    );
    _studySessionsSub = repository.watchStudySessions(userId).listen(
      (sessions) =>
          _updateState(studySessions: sessions, isLoading: false, errorMessage: null),
      onError: (error) => _updateState(errorMessage: error.toString()),
    );
  }

  void _updateState({
    List<LongTermGoal>? goals,
    List<Milestone>? milestones,
    List<HomeAssignment>? assignments,
    List<StudyBlock>? studyBlocks,
    List<StudySession>? studySessions,
    bool? isLoading,
    String? errorMessage,
    DateTime? selectedDay,
    DateTime? weekStart,
  }) {
    _state = _state.copyWith(
      goals: goals,
      milestones: milestones,
      assignments: assignments,
      studyBlocks: studyBlocks,
      studySessions: studySessions,
      isLoading: isLoading,
      errorMessage: errorMessage,
      selectedDay: selectedDay,
      weekStart: weekStart,
    );
    notifyListeners();
  }

  void selectDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    _updateState(
      selectedDay: normalized,
      weekStart: _startOfWeek(normalized),
    );
  }

  List<HomeAssignment> assignmentsForDay(DateTime day) {
    return _state.assignments.where((assignment) {
      return _isSameDay(assignment.deadline, day);
    }).toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
  }

  List<StudyBlock> studyBlocksForDay(DateTime day) {
    return _state.studyBlocks.where((block) => _isSameDay(block.scheduledAt, day)).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  int assignmentsCountForDay(DateTime day) =>
      assignmentsForDay(day).length;

  int milestonesDueCountForDay(DateTime day) {
    return _state.milestones
        .where((milestone) => milestone.dueDate != null && _isSameDay(milestone.dueDate!, day))
        .length;
  }

  List<HomeTask> tasksForDay(DateTime day) {
    final assignments = assignmentsForDay(day).map(HomeTask.assignment);
    final blocks = studyBlocksForDay(day).map(HomeTask.studyBlock);
    final combined = [...assignments, ...blocks];
    combined.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return combined;
  }

  HomeTask? get focusTask {
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 7));

    // Prioritize sessions that were left incomplete/partial.
    final pendingSessions = _state.studySessions.where(
      (session) => session.completionStatus == 'abandoned',
    );
    for (final session in pendingSessions) {
      if (session.assignmentId != null) {
        HomeAssignment? assignment;
        try {
          assignment = _state.assignments
              .firstWhere((a) => a.id == session.assignmentId);
        } catch (_) {
          assignment = null;
        }
        if (assignment != null && assignment.deadline.isAfter(now)) {
          return HomeTask.assignment(assignment);
        }
      }
      if (session.studyBlockId != null) {
        StudyBlock? block;
        try {
          block = _state.studyBlocks
              .firstWhere((b) => b.id == session.studyBlockId);
        } catch (_) {
          block = null;
        }
        if (block != null && !block.isCompleted) {
          return HomeTask.studyBlock(block);
        }
      }
    }

    final blockCandidates = _state.studyBlocks.where(
      (block) =>
          !block.isCompleted &&
          block.scheduledAt.isAfter(now.subtract(const Duration(days: 1))) &&
          block.scheduledAt.isBefore(horizon),
    );
    final sortedBlocks = blockCandidates.toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    if (sortedBlocks.isNotEmpty) {
      return HomeTask.studyBlock(sortedBlocks.first);
    }
    final upcomingAssignments = _state.assignments.where(
      (a) =>
          !a.isCompleted &&
          a.deadline.isAfter(now) &&
          a.deadline.isBefore(horizon),
    );
    final sortedAssignments = upcomingAssignments.toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
    final goalLinked = sortedAssignments.where((a) => a.goalId != null);
    if (goalLinked.isNotEmpty) {
      return HomeTask.assignment(goalLinked.first);
    }
    return sortedAssignments.isNotEmpty ? HomeTask.assignment(sortedAssignments.first) : null;
  }

  double goalProgress(String goalId) {
    final details = milestoneDetailsForGoal(goalId);
    if (details.isEmpty) return 0;
    final totalProgress = details.fold<double>(
      0,
      (acc, detail) => acc + detail.progress,
    );
    return (totalProgress / details.length).clamp(0, 1);
  }

  String? goalTitle(String? goalId) {
    if (goalId == null) return null;
    try {
      return _state.goals.firstWhere((goal) => goal.id == goalId).title;
    } catch (_) {
      return null;
    }
  }

  List<Milestone> milestonesForGoal(String goalId) {
    return _state.milestones.where((milestone) => milestone.goalId == goalId).toList()
      ..sort((a, b) {
        final aDate = a.dueDate ?? DateTime(2100);
        final bDate = b.dueDate ?? DateTime(2100);
        return aDate.compareTo(bDate);
      });
  }

  List<MilestoneProgressInfo> milestoneDetailsForGoal(String goalId) {
    return milestonesForGoal(goalId).map(milestoneProgressInfo).toList();
  }

  MilestoneProgressInfo milestoneProgressInfo(Milestone milestone) {
    final linkedAssignments = milestone.linkedAssignmentIds
        .map((id) => _assignmentById(id))
        .whereType<HomeAssignment>()
        .toList();
    final linkedSessions = milestone.linkedSessionIds
        .map((id) => _sessionById(id))
        .whereType<StudySession>()
        .toList();
    final completedAssignments =
        linkedAssignments.where((assignment) => assignment.isCompleted).length;
    final completedSessions = linkedSessions
        .where((session) => session.completionStatus == 'completed')
        .length;
    final totalLinked = linkedAssignments.length + linkedSessions.length;
    final completedLinked = completedAssignments + completedSessions;
    final ratio = totalLinked == 0
        ? (milestone.isCompleted ? 1.0 : 0.0)
        : completedLinked / totalLinked;
    return MilestoneProgressInfo(
      milestone: milestone,
      linkedAssignments: linkedAssignments,
      linkedSessions: linkedSessions,
      completedAssignments: completedAssignments,
      completedSessions: completedSessions,
      totalLinked: totalLinked,
      completedLinked: completedLinked,
      progress: ratio.clamp(0, 1),
    );
  }

  String goalMilestoneSummary(String goalId) {
    final details = milestoneDetailsForGoal(goalId);
    if (details.isEmpty) return 'No milestones yet';
    final completed =
        details.where((detail) => detail.milestone.isCompleted).length;
    return '$completed/${details.length} milestones completed';
  }

  WeeklySummary get weeklySummary {
    final weekEnd = _state.weekStart.add(const Duration(days: 7));

    final weeklyAssignments = _state.assignments.where((assignment) {
      return assignment.deadline.isAfter(_state.weekStart.subtract(const Duration(days: 1))) &&
          assignment.deadline.isBefore(weekEnd);
    });

    final totalMinutes = weeklyAssignments.where((a) => a.isCompleted).fold<int>(
      0,
      (accumulator, assignment) => accumulator + (assignment.estimatedMinutes ?? 0),
    );

    final weeklyMilestones = _state.milestones.where((milestone) {
      final dueDate = milestone.dueDate;
      if (dueDate == null) return false;
      return dueDate.isAfter(_state.weekStart.subtract(const Duration(days: 1))) &&
          dueDate.isBefore(weekEnd);
    }).toList();

    final completedMilestones =
        weeklyMilestones.where((milestone) => milestone.isCompleted).length;

    return WeeklySummary(
      totalStudyTime: Duration(minutes: totalMinutes),
      completedMilestones: completedMilestones,
      totalMilestones: weeklyMilestones.length,
      streakDays: _studyStreak(),
    );
  }

  int _studyStreak() {
    final normalizedToday = DateTime.now();
    var streak = 0;
    for (var offset = 0; offset < 30; offset++) {
      final day =
          DateTime(normalizedToday.year, normalizedToday.month, normalizedToday.day)
              .subtract(Duration(days: offset));
      final hasCompletedAssignment = _state.assignments.any(
        (assignment) => assignment.isCompleted && _isSameDay(assignment.deadline, day),
      );
      final hasCompletedMilestone = _state.milestones.any(
        (milestone) => milestone.isCompleted && milestone.dueDate != null && _isSameDay(milestone.dueDate!, day),
      );
      if (hasCompletedAssignment || hasCompletedMilestone) {
        streak += 1;
      } else {
        break;
      }
    }
    return streak;
  }

  Future<void> toggleAssignmentCompletion(String assignmentId, bool isCompleted) {
    return repository.toggleAssignmentCompletion(
      userId: userId,
      assignmentId: assignmentId,
      isCompleted: isCompleted,
    );
  }

  Future<void> toggleMilestoneCompletion(String goalId, String milestoneId, bool isCompleted) async {
    final previousState = _state.milestones;
    final updatedMilestones = previousState
        .map(
          (milestone) => milestone.id == milestoneId
              ? milestone.copyWith(isCompleted: isCompleted)
              : milestone,
        )
        .toList();
    _updateState(milestones: updatedMilestones);
    try {
      await repository.toggleMilestoneCompletion(
        userId: userId,
        goalId: goalId,
        milestoneId: milestoneId,
        isCompleted: isCompleted,
      );
    } catch (error) {
      _updateState(milestones: previousState);
      rethrow;
    }
  }

  Future<void> deleteGoal(String goalId) {
    return repository.deleteGoal(userId: userId, goalId: goalId);
  }

  Future<void> createGoal({
    required String title,
    String? description,
    GoalCategory category = GoalCategory.exam,
    DateTime? targetDate,
    int priority = 1,
    List<Milestone> milestones = const [],
  }) {
    return repository.createGoal(
      userId: userId,
      title: title,
      description: description,
      category: category,
      targetDate: targetDate,
      priority: priority,
      milestones: milestones,
    );
  }

  Future<void> createOrUpdateBlock({
    String? blockId,
    required String title,
    required DateTime scheduledAt,
    required int durationMinutes,
    String? subject,
    String? goalId,
    String? assignmentId,
    String? milestoneId,
    bool reminderEnabled = false,
  }) {
    if (blockId == null) {
      return repository.createStudyBlock(
        userId: userId,
        title: title,
        scheduledAt: scheduledAt,
        durationMinutes: durationMinutes,
        subject: subject,
        goalId: goalId,
        assignmentId: assignmentId,
        milestoneId: milestoneId,
        reminderEnabled: reminderEnabled,
      );
    } else {
      return repository.updateStudyBlock(
        userId: userId,
        blockId: blockId,
        data: {
          'title': title,
          'subject': subject,
          'scheduledAt': Timestamp.fromDate(scheduledAt),
          'durationMinutes': durationMinutes,
          'goalId': goalId,
          'assignmentId': assignmentId,
          'milestoneId': milestoneId,
          'reminderEnabled': reminderEnabled,
        },
      );
    }
  }

  Future<void> deleteStudyBlock(String blockId) {
    return repository.deleteStudyBlock(userId: userId, blockId: blockId);
  }

  Future<void> markStudyBlockCompleted(String blockId, bool isCompleted) {
    return repository.updateStudyBlock(
      userId: userId,
      blockId: blockId,
      data: {'isCompleted': isCompleted},
    );
  }

  @override
  void dispose() {
    _goalsSub?.cancel();
    _milestonesSub?.cancel();
    _assignmentsSub?.cancel();
    _studyBlocksSub?.cancel();
    _studySessionsSub?.cancel();
    super.dispose();
  }

  HomeAssignment? _assignmentById(String id) {
    try {
      return _state.assignments.firstWhere((assignment) => assignment.id == id);
    } catch (_) {
      return null;
    }
  }

  StudySession? _sessionById(String id) {
    try {
      return _state.studySessions.firstWhere((session) => session.id == id);
    } catch (_) {
      return null;
    }
  }

  StudySession? activeSessionForAssignment(String assignmentId) {
    try {
      return _state.studySessions.firstWhere(
        (session) =>
            session.assignmentId == assignmentId &&
            session.completionStatus == 'ongoing',
      );
    } catch (_) {
      return null;
    }
  }

  StudySession? activeSessionForStudyBlock(String blockId) {
    try {
      return _state.studySessions.firstWhere(
        (session) =>
            session.studyBlockId == blockId &&
            session.completionStatus == 'ongoing',
      );
    } catch (_) {
      return null;
    }
  }

  bool hasActiveSessionForTask(HomeTask task) {
    if (task.type == HomeTaskType.assignment) {
      final assignmentId = task.assignment?.id;
      if (assignmentId == null) return false;
      return activeSessionForAssignment(assignmentId) != null;
    } else {
      final blockId = task.studyBlock?.id;
      if (blockId == null) return false;
      return activeSessionForStudyBlock(blockId) != null;
    }
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime _startOfWeek(DateTime date) {
  final weekday = date.weekday;
  final difference = weekday - DateTime.monday;
  return DateTime(date.year, date.month, date.day).subtract(Duration(days: difference));
}

enum HomeTaskType { assignment, studyBlock }

class HomeTask {
  final HomeTaskType type;
  final HomeAssignment? assignment;
  final StudyBlock? studyBlock;

  HomeTask._(this.type, this.assignment, this.studyBlock);

  factory HomeTask.assignment(HomeAssignment assignment) {
    return HomeTask._(HomeTaskType.assignment, assignment, null);
  }

  factory HomeTask.studyBlock(StudyBlock block) {
    return HomeTask._(HomeTaskType.studyBlock, null, block);
  }

  DateTime get scheduledTime {
    if (type == HomeTaskType.studyBlock) {
      return studyBlock!.scheduledAt;
    }
    return assignment!.deadline;
  }
}

class MilestoneProgressInfo {
  MilestoneProgressInfo({
    required this.milestone,
    required this.linkedAssignments,
    required this.linkedSessions,
    required this.completedAssignments,
    required this.completedSessions,
    required this.totalLinked,
    required this.completedLinked,
    required this.progress,
  });

  final Milestone milestone;
  final List<HomeAssignment> linkedAssignments;
  final List<StudySession> linkedSessions;
  final int completedAssignments;
  final int completedSessions;
  final int totalLinked;
  final int completedLinked;
  final double progress;

  bool get hasLinkedWork => totalLinked > 0;
}
