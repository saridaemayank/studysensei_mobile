import 'package:flutter/material.dart';

class ConceptSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;
  final bool enabled;

  const ConceptSearchField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hint ?? 'Search for a concept...',
        hintStyle: theme.textTheme.bodyLarge?.copyWith(
          color: theme.hintColor,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: theme.hintColor,
        ),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.clear_rounded,
                  color: theme.hintColor,
                ),
                onPressed: () {
                  controller.clear();
                  onChanged?.call('');
                  onClear?.call();
                },
              )
            : null,
        filled: true,
        fillColor: theme.cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
    );
  }
}
