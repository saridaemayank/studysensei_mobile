import 'package:flutter/material.dart';
import 'package:study_sensei/core/theme/app_colors.dart';
import 'package:study_sensei/core/theme/app_typography.dart';
import 'package:study_sensei/features/common/widgets/sensei_primary_button.dart';

class DojoEmptyState extends StatelessWidget {
  final VoidCallback? onCreate;
  const DojoEmptyState({super.key, this.onCreate});
  @override
  Widget build(BuildContext context) => Center(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.groups_outlined,
              size: 48, color: AppColors.primaryLight),
          const SizedBox(height: 24),
          const Text('Studying is better together.',
              textAlign: TextAlign.center, style: AppTypography.sectionTitle),
          const SizedBox(height: 12),
          const Text('Join a Dojo or create one with your friends.',
              textAlign: TextAlign.center, style: AppTypography.bodyLarge),
          if (onCreate != null) ...[
            const SizedBox(height: 24),
            SenseiPrimaryButton(text: 'Create Dojo', onPressed: onCreate),
          ],
        ]),
      ));
}
