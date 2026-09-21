import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized typography scales for StudySensei.
/// Leverages existing project fonts with clear hierarchy.
class AppTypography {
  AppTypography._();

  static const String headingFont = 'Headings';
  static const String bodyFont = 'SubHeading';

  // Page Title (28–32px)
  static const TextStyle pageTitle = TextStyle(
    fontFamily: headingFont,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  // Section Title (18–22px)
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: bodyFont,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );

  // Card Header / Subtitle (16–18px)
  static const TextStyle cardTitle = TextStyle(
    fontFamily: bodyFont,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // Body Large (15–16px)
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: bodyFont,
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // Body Medium (13–14px)
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: bodyFont,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // Button Label (15–16px)
  static const TextStyle button = TextStyle(
    fontFamily: bodyFont,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.2,
  );

  // Caption / Secondary (12–13px)
  static const TextStyle caption = TextStyle(
    fontFamily: bodyFont,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textTertiary,
    height: 1.3,
  );
}
