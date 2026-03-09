import 'package:flutter/material.dart';

/// Design tokens — clean neutral palette with restrained semantic color.
/// Rule: 90% neutral + 10% semantic. Color is only for meaning, never decoration.
abstract final class AppColors {
  // ── Backgrounds (light) ──
  static const background = Color(0xFFFAFAF9);
  static const card = Color(0xFFFFFFFF);
  static const surfaceSecondary = Color(0xFFF5F5F3);

  // ── Backgrounds (dark) ──
  static const backgroundDark = Color(0xFF101010);
  static const cardDark = Color(0xFF1A1A1A);
  static const surfaceSecondaryDark = Color(0xFF222222);

  // ── Text (light) ──
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF71717A);
  static const textPlaceholder = Color(0xFFA1A1AA);

  // ── Text (dark) ──
  static const textPrimaryDark = Color(0xFFF4F4F5);
  static const textSecondaryDark = Color(0xFFA1A1AA);

  // ── Semantic: only for status dots, primary buttons, small labels ──
  static const accent = Color(0xFF2563EB);
  static const accentPressed = Color(0xFF1D4ED8);
  static const accentDisabled = Color(0xFF93C5FD);
  static const accentDark = Color(0xFF5B8DEF);

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFCA8A04);
  static const error = Color(0xFFDC2626);

  // ── Surfaces & borders ──
  static const separator = Color(0xFFE4E4E7);
  static const separatorDark = Color(0xFF2C2C2C);
  static const inputFill = Color(0xFFF4F4F5);
  static const inputFillDark = Color(0xFF262626);
  static const buttonOutline = Color(0xFFD4D4D8);
}
