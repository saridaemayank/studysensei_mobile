import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/providers/user_provider.dart';
import '../../../calendar/services/add_assignment.dart';
import '../../data/models/long_term_goal.dart';
import '../../data/models/milestone.dart';
import '../../data/models/study_block.dart';
import '../controller/home_view_model.dart';
import '../widgets/daily_task_list.dart';
import '../widgets/focus_today_card.dart';
import '../widgets/long_term_goals_section.dart';
import '../widgets/weekly_calendar_strip.dart';
import 'goal_create_sheet.dart';
import 'goal_details_sheet.dart';
import 'study_block_sheet.dart';
import 'study_session_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final firstName = (userProvider.userPreferences?.name?.split(' ').first ??
        userProvider.user?.displayName ??
        'Sensei');
    final subtitle = 'Let\'s plan today for your long-term goals.';

    return Consumer<HomeViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.state;
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        final tasksForDay = viewModel.tasksForDay(state.selectedDay);
        final focusTask = viewModel.focusTask;
        return Scaffold(
          appBar: AppBar(
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.orange[100],
            elevation: 0,
            centerTitle: true,
            title: Text(
              'Hi, $firstName',
              style: const TextStyle(
                fontFamily: 'DancingScript',
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Your Focus Today',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  FocusTodayCard(
                    task: focusTask,
                    goalTitleResolver: viewModel.goalTitle,
                    onStartSession: (task) => _startSession(context, task, viewModel),
                    onPlanNew: () => _openStudyBlockSheet(context, viewModel),
                    hasActiveSession: viewModel.hasActiveSessionForTask,
                  ),
                  const SizedBox(height: 32),
                  LongTermGoalsSection(
                    goals: state.goals,
                    onAddGoal: () => _openCreateGoalSheet(context, viewModel),
                    onViewAll: state.goals.isEmpty
                        ? null
                        : () => _openGoalsOverview(context, viewModel),
                    onGoalSelected: (goal) => _openGoalDetails(context, goal, viewModel),
                    progressForGoal: viewModel.goalProgress,
                    statusForGoal: viewModel.goalMilestoneSummary,
                  ),
                  const SizedBox(height: 32),
                  WeeklyCalendarStrip(
                    focusedDay: state.selectedDay,
                    selectedDay: state.selectedDay,
                    onDaySelected: viewModel.selectDay,
                    onPageChanged: viewModel.selectDay,
                    assignmentCountForDay: viewModel.assignmentsCountForDay,
                    milestoneCountForDay: viewModel.milestonesDueCountForDay,
                  ),
                  const SizedBox(height: 20),
                  DailyTaskList(
                    tasks: tasksForDay,
                    onToggleCompletion: (assignment, value) =>
                        viewModel.toggleAssignmentCompletion(assignment.id, value),
                    goalTitleResolver: viewModel.goalTitle,
                    onStartSession: (task) => _startSession(context, task, viewModel),
                    onEditStudyBlock: (block) =>
                        _openStudyBlockSheet(context, viewModel, existingBlock: block),
                    onDeleteStudyBlock: (block) async {
                      try {
                        await viewModel.deleteStudyBlock(block.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Deleted "${block.title}"')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Unable to delete block: $e')),
                          );
                        }
                      }
                    },
                    hasActiveSession: viewModel.hasActiveSessionForTask,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showCreateMenu(context, viewModel),
            label: const Text('New'),
            icon: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Future<void> _startSession(
    BuildContext context,
    HomeTask task,
    HomeViewModel viewModel,
  ) async {
    final now = DateTime.now();
    if (task.type == HomeTaskType.assignment &&
        task.assignment != null &&
        !task.assignment!.deadline.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This assignment deadline has passed. Plan a new block instead.'),
        ),
      );
      return;
    }
    final hasExistingSession = viewModel.hasActiveSessionForTask(task);
    int? durationOverride;
    if (!hasExistingSession) {
      final initialDuration = task.type == HomeTaskType.studyBlock
          ? task.studyBlock?.durationMinutes ?? 25
          : task.assignment?.estimatedMinutes ?? 25;
      durationOverride = await _promptSessionDuration(
        context,
        initialDuration,
      );
      if (durationOverride == null) {
        return;
      }
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudySessionScreen(
          assignment: task.assignment,
          studyBlock: task.studyBlock,
          durationMinutesOverride: durationOverride,
        ),
      ),
    );
  }

  void _showCreateMenu(BuildContext context, HomeViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.assignment_add),
              title: const Text('New Assignment'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AddAssignmentPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('New Study Block'),
              onTap: () {
                Navigator.of(context).pop();
                _openStudyBlockSheet(context, viewModel);
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag),
              title: const Text('New Long-Term Goal'),
              onTap: () {
                Navigator.of(context).pop();
                _openCreateGoalSheet(context, viewModel);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateGoalSheet(BuildContext context, HomeViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => GoalCreateSheet(
        onCreateGoal: ({
          required String title,
          String? description,
          GoalCategory category = GoalCategory.exam,
          DateTime? targetDate,
          int priority = 1,
          List<Milestone> milestones = const [],
        }) {
          return viewModel.createGoal(
            title: title,
            description: description,
            category: category,
            targetDate: targetDate,
            priority: priority,
            milestones: milestones,
          );
        },
      ),
    );
  }

  Future<int?> _promptSessionDuration(
      BuildContext context, int initialMinutes) async {
    final controller =
        TextEditingController(text: initialMinutes.clamp(1, 180).toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set study session length'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Minutes',
            hintText: 'Enter duration in minutes',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed == null || parsed <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid duration.')),
                );
                return;
              }
              Navigator.of(context).pop(parsed);
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
    return result;
  }

  void _openStudyBlockSheet(
    BuildContext context,
    HomeViewModel viewModel, {
    StudyBlock? existingBlock,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StudyBlockSheet(
        initialBlock: existingBlock,
        goals: viewModel.state.goals,
        assignments: viewModel.state.assignments,
        onSubmit: ({
          required String title,
          required DateTime scheduledAt,
          required int durationMinutes,
          String? subject,
          String? goalId,
          String? assignmentId,
          bool reminderEnabled = false,
        }) {
          return viewModel.createOrUpdateBlock(
            blockId: existingBlock?.id,
            title: title,
            scheduledAt: scheduledAt,
            durationMinutes: durationMinutes,
            subject: subject,
            goalId: goalId,
            assignmentId: assignmentId,
            reminderEnabled: reminderEnabled,
          );
        },
      ),
    );
  }

  void _openGoalsOverview(
    BuildContext context,
    HomeViewModel viewModel,
  ) {
    final goals = viewModel.state.goals;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                'Your long-term goals',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (goals.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No goals added yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                ...goals.map(
                  (goal) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(goal.title),
                    subtitle: Text(
                      '${(viewModel.goalProgress(goal.id) * 100).round()}% complete',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).pop();
                      _openGoalDetails(context, goal, viewModel);
                    },
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openCreateGoalSheet(context, viewModel);
                },
                icon: const Icon(Icons.add),
                label: const Text('New goal'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openGoalDetails(
    BuildContext context,
    LongTermGoal goal,
    HomeViewModel viewModel,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ChangeNotifierProvider.value(
        value: viewModel,
        child: GoalDetailsSheet(
          goal: goal,
          onToggleMilestone: (milestone, value) =>
              viewModel.toggleMilestoneCompletion(
            goal.id,
            milestone.id,
            value,
          ),
          onDeleteGoal: () async {
            await viewModel.deleteGoal(goal.id);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}
