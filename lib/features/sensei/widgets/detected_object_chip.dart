import 'package:flutter/material.dart';

class DetectedObjectChip extends StatelessWidget {
  final String label;
  final VoidCallback? onRemove;
  final bool isRemovable;
  final Color? color;

  const DetectedObjectChip({
    super.key,
    required this.label,
    this.onRemove,
    this.isRemovable = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chipColor = color ?? colorScheme.primaryContainer;
    final textColor = color != null 
        ? Colors.white 
        : colorScheme.onPrimaryContainer;

    return Container(
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isRemovable) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onRemove,
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: textColor.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
