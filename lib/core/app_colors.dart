import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static bool isDark = false;

  static void updateTheme(bool dark) {
    isDark = dark;
  }

  // Brand
  static Color get primary => isDark ? const Color(0xFF829079) : const Color(0xFF5E6B56);      // Dark forest green / lighter sage in dark mode for contrast
  static Color get primaryLight => isDark ? const Color(0xFFA8B5A2) : const Color(0xFF829079);
  static Color get primaryDark => isDark ? const Color(0xFF3C4636) : const Color(0xFF3C4636);
  static Color get accent => isDark ? const Color(0xFF829079) : const Color(0xFF5E6B56);
  static Color get accentGold => isDark ? const Color(0xFFA8B5A2) : const Color(0xFF8B9B82);   // Sagey gold
  static Color get accentGreen => isDark ? const Color(0xFF829079) : const Color(0xFF5E6B56);
  static Color get accentOrange => isDark ? const Color(0xFFA8B5A2) : const Color(0xFF829079);

  // Backgrounds
  static Color get background => isDark ? const Color(0xFF1E231C) : const Color(0xFFF2EFEA);   // Warm cream / Deep earthy dark green-gray
  static Color get surface => isDark ? const Color(0xFF2A3027) : const Color(0xFFFFFFFF);      // Card surface / slate/sage dark card
  static Color get surfaceLight => isDark ? const Color(0xFF3D473A) : const Color(0xFFA8B5A2); // Sage green border/detail
  static Color get gridBg => isDark ? const Color(0xFF1E231C) : const Color(0xFFF2EFEA);       // Grid background

  // Arrow direction colors — solid dark green for maximum legibility in light, clean cream/sage in dark
  static Color get arrowUp    => isDark ? const Color(0xFFECF0EB) : const Color(0xFF3C4636);
  static Color get arrowDown  => isDark ? const Color(0xFFECF0EB) : const Color(0xFF3C4636);
  static Color get arrowLeft  => isDark ? const Color(0xFFECF0EB) : const Color(0xFF3C4636);
  static Color get arrowRight => isDark ? const Color(0xFFECF0EB) : const Color(0xFF3C4636);

  // Difficulty colors
  static Color get easy => isDark ? const Color(0xFFA8B5A2) : const Color(0xFF829079);
  static Color get medium => isDark ? const Color(0xFF96A390) : const Color(0xFF708066);
  static Color get hard => isDark ? const Color(0xFF829079) : const Color(0xFF5E6B56);
  static Color get expert => isDark ? const Color(0xFF6F7C66) : const Color(0xFF4C5745);
  static Color get master => isDark ? const Color(0xFF5E6B56) : const Color(0xFF3C4636);

  // Text
  static Color get textPrimary => isDark ? const Color(0xFFECF0EB) : const Color(0xFF3C4636);
  static Color get textSecondary => isDark ? const Color(0xFFBDC7B9) : const Color(0xFF5E6B56);
  static Color get textMuted => isDark ? const Color(0xFF8A9885) : const Color(0xFF829079);

  // UI Elements
  static Color get heartRed => isDark ? const Color(0xFFA8B5A2) : const Color(0xFF5E6B56);
  static Color get heartEmpty => isDark ? const Color(0xFF3D473A) : const Color(0xFFD3CFC9);
  static Color get streakFire => isDark ? const Color(0xFFA8B5A2) : const Color(0xFF5E6B56);
  static Color get coinGold => isDark ? const Color(0xFFF1C40F) : const Color(0xFF829079);
  static Color get starYellow => isDark ? const Color(0xFFA8B5A2) : const Color(0xFF5E6B56);
  static Color get borderGlow => isDark ? const Color(0xFF829079) : const Color(0xFF5E6B56);

  // Gradients
  static LinearGradient get primaryGradient => LinearGradient(
    colors: isDark 
      ? [const Color(0xFF4C5745), const Color(0xFF5E6B56)]
      : [const Color(0xFF5E6B56), const Color(0xFF7A8972)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get secondaryGradient => LinearGradient(
    colors: isDark
      ? [const Color(0xFF3D473A), const Color(0xFF4C5745)]
      : [const Color(0xFFA8B5A2), const Color(0xFFC0CDC0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get bgGradient => LinearGradient(
    colors: isDark
      ? [const Color(0xFF1E231C), const Color(0xFF141912)]
      : [const Color(0xFFF2EFEA), const Color(0xFFE2DFDA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient get successGradient => LinearGradient(
    colors: isDark
      ? [const Color(0xFF3D473A), const Color(0xFF4C5745)]
      : [const Color(0xFF5E6B56), const Color(0xFF708066)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get dangerGradient => LinearGradient(
    colors: isDark
      ? [const Color(0xFF6B3E36), const Color(0xFF82524A)]
      : [const Color(0xFF8B5E56), const Color(0xFFA27870)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
