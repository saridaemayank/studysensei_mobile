import 'package:flutter/material.dart';

class SubjectChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;
  final Color? color;
  final double borderRadius;

  const SubjectChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.color,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = color ?? colorScheme.primary;

    return FilterChip(
      label: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: colorScheme.surface,
      selectedColor: primaryColor,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? primaryColor : theme.dividerColor,
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      showCheckmark: true,
      labelPadding: const EdgeInsets.symmetric(horizontal: 0),
    );
  }
}
