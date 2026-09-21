import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/sensei_mode.dart';

class SenseiModeSwitch extends StatelessWidget {
  final SenseiMode value;
  final ValueChanged<SenseiMode> onChanged;
  const SenseiModeSwitch(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final color =
        value == SenseiMode.doubt ? AppColors.primary : AppColors.info;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);
    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderSubtle)),
      child: Stack(children: [
        AnimatedAlign(
          duration: duration,
          curve: Curves.easeInOutCubic,
          alignment: value == SenseiMode.doubt
              ? Alignment.centerLeft
              : Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: .5,
            heightFactor: 1,
            child: AnimatedContainer(
              duration: duration,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .16),
                border: Border.all(color: color.withValues(alpha: .65)),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: .12), blurRadius: 14)
                ],
              ),
            ),
          ),
        ),
        Row(children: [
          for (final mode in SenseiMode.values)
            Expanded(
                child: Semantics(
              label: mode == SenseiMode.doubt ? 'Doubt' : 'Explain',
              button: true,
              selected: value == mode,
              inMutuallyExclusiveGroup: true,
              excludeSemantics: true,
              onTap: () => onChanged(mode),
              child: TextButton(
                onPressed: () => onChanged(mode),
                style: TextButton.styleFrom(
                    foregroundColor: value == mode
                        ? AppColors.textPrimary
                        : AppColors.textSecondary),
                child: Text(mode == SenseiMode.doubt ? 'Doubt' : 'Explain',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            )),
        ]),
      ]),
    );
  }
}
