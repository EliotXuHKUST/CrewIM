import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Backgrounds ──
  static const background = Color(0xFFF8F8F6);
  static const card = Color(0xFFFFFFFF);
  static const surfaceSecondary = Color(0xFFF2F2EF);

  // ── Text ──
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B6B6B);
  static const textPlaceholder = Color(0xFF9E9E9E);

  // ── Brand accent — warm indigo, not default Material blue ──
  static const accent = Color(0xFF4338CA);
  static const accentLight = Color(0xFFEEF2FF);
  static const accentPressed = Color(0xFF3730A3);
  static const accentDisabled = Color(0xFFA5B4FC);

  // ── Semantic ──
  static const success = Color(0xFF059669);
  static const successLight = Color(0xFFECFDF5);
  static const warning = Color(0xFFD97706);
  static const warningLight = Color(0xFFFFFBEB);
  static const error = Color(0xFFDC2626);
  static const errorLight = Color(0xFFFEF2F2);

  // ── Surfaces & borders ──
  static const separator = Color(0xFFE5E5E3);
  static const inputFill = Color(0xFFF5F5F3);
  static const buttonOutline = Color(0xFFD5D5D3);

  // ── Dark mode (kept for compatibility but not active) ──
  static const backgroundDark = Color(0xFF0F0F0F);
  static const cardDark = Color(0xFF1A1A1A);
  static const surfaceSecondaryDark = Color(0xFF222222);
  static const textPrimaryDark = Color(0xFFF4F4F5);
  static const textSecondaryDark = Color(0xFFA1A1AA);
  static const separatorDark = Color(0xFF2C2C2C);
  static const inputFillDark = Color(0xFF262626);
  static const accentDark = Color(0xFF818CF8);
}
