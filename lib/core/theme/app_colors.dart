import 'package:flutter/material.dart';

/// Centralized color palette for StudySensei.
/// Dark visual identity: deep navy, near-black, electric indigo/violet accent,
/// and canonical semantic colors.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFF07111F);
  static const Color surface = Color(0xFF0B1626);
  static const Color surfaceElevated = Color(0xFF101C2C);
  static const Color surfaceHighlight = Color(0xFF16253B);

  // Primary Brand Accent
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF827BFF);

  // Canonical Semantic Colors
  static const Color success = Color(0xFF22C55E); // Explain / verified
  static const Color error = Color(0xFFEF4444); // Check my work / error
  static const Color warning = Color(0xFFF59E0B); // Hint / attention
  static const Color info = Color(0xFF38BDF8); // Informational note

  // Text Hierarchy
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF475569);

  // Borders & Dividers
  static const Color borderSubtle = Color(0x1AFFFFFF); // 10% white
  static const Color borderMedium = Color(0x33FFFFFF); // 20% white
  static const Color borderActive = Color(0x666C63FF);

  // Glows & Shadows
  static const Color primaryGlow = Color(0x336C63FF);
  static const Color shadow = Color(0x40000000);
}
