import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'exam_dojo_dashboard_screen.dart';
import 'exam_dojo_empty_state_screen.dart';
import 'exam_dojo_setup_flow_screen.dart';
import '../controller/exam_dojo_controller.dart';

class ExamDojoTabScreen extends StatefulWidget {
  const ExamDojoTabScreen({super.key});

  @override
  State<ExamDojoTabScreen> createState() => _ExamDojoTabScreenState();
}

class _ExamDojoTabScreenState extends State<ExamDojoTabScreen> {
  void _startSetup() {
    final controller = context.read<ExamDojoController>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: controller,
          child: const ExamDojoSetupFlowScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExamDojoController>(
      builder: (context, controller, _) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage != null) {
          return Center(child: Text(controller.errorMessage!));
        }
        if (controller.dojo == null) {
          return ExamDojoEmptyStateScreen(onStart: _startSetup);
        }
        if (!controller.isBlocksLoading &&
            controller.blocksError == null &&
            controller.dailyBlocks.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            controller.ensureDailyBlocks();
          });
        }
        return ExamDojoDashboardScreen(
          onOpenSetup: _startSetup,
          dojo: controller.dojo!,
          dailyBlocks: controller.dailyBlocks,
          isBlocksLoading: controller.isBlocksLoading,
          blocksError: controller.blocksError,
          onRetryBlocks: controller.retryDailyBlocks,
          subjectProgressById: controller.subjectProgressById,
          subjectProgressByName: controller.subjectProgressByName,
          myProgress: controller.myProgressRatio,
          groupProgress: controller.groupProgressRatio,
          isProgressLoading: controller.isProgressLoading,
          hasGroupProgress: controller.hasGroupProgress,
          onRefreshProgress: controller.refreshProgress,
        );
      },
    );
  }
}
