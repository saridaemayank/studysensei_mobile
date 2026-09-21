import 'package:flutter_test/flutter_test.dart';
import 'package:study_sensei/core/theme/app_colors.dart';
import 'package:study_sensei/core/theme/app_theme.dart';

void main() {
  test('AppTheme dark theme smoke test', () {
    final theme = AppTheme.darkTheme;
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.primary, AppColors.primary);
  });
}
