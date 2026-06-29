import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF22252A);      // Dark gray / almost black
  static const Color primaryLight = Color(0xFF3F444D);
  static const Color primaryDark = Color(0xFF141619);
  static const Color accent = Color(0xFFB33939);       // Warm red
  static const Color accentGold = Color(0xFFC08255);   // Soft gold
  static const Color accentGreen = Color(0xFF4A7C59);  // Forest green
  static const Color accentOrange = Color(0xFFC8703F); // Warm orange

  // Backgrounds
  static const Color background = Color(0xFFF7F1E5);   // Warm cream background
  static const Color surface = Color(0xFFFFFDF9);      // Card surface
  static const Color surfaceLight = Color(0xFFEFE9DC); // Light surface
  static const Color gridBg = Color(0xFFF7F1E5);      // Grid background

  // Arrow direction colors — solid black for maximum legibility
  static const Color arrowUp    = Color(0xFF1A1A1A);
  static const Color arrowDown  = Color(0xFF1A1A1A);
  static const Color arrowLeft  = Color(0xFF1A1A1A);
  static const Color arrowRight = Color(0xFF1A1A1A);

  // Difficulty colors
  static const Color easy = Color(0xFF4A7C59);
  static const Color medium = Color(0xFFC08255);
  static const Color hard = Color(0xFFC8703F);
  static const Color expert = Color(0xFFB33939);
  static const Color master = Color(0xFF7A4A75);

  // Text
  static const Color textPrimary = Color(0xFF6E503F);
  static const Color textSecondary = Color(0xFF8B7365);
  static const Color textMuted = Color(0xFFB5A79E);

  // UI Elements
  static const Color heartRed = Color(0xFFB33939);
  static const Color heartEmpty = Color(0xFFDDD5C3);
  static const Color streakFire = Color(0xFFC8703F);
  static const Color coinGold = Color(0xFFC08255);
  static const Color starYellow = Color(0xFFC08255);
  static const Color borderGlow = Color(0xFF6E503F);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6E503F), Color(0xFF8B7365)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFFF7F1E5), Color(0xFFF5EFEB)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF4A7C59), Color(0xFF6C9C7B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFB33939), Color(0xFFCC5A5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
