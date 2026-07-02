import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/app_colors.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/main_menu/main_menu_screen.dart';
import 'screens/level_select/level_select_screen.dart';
import 'screens/game/game_screen.dart';
import 'screens/game_over/game_over_screen.dart';
import 'screens/settings/settings_screen.dart';

class ArrowPuzzleApp extends StatelessWidget {
  const ArrowPuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arrow Escape',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.nunitoTextTheme(
          ThemeData.light().textTheme,
        ),
        scaffoldBackgroundColor: AppColors.background,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/menu': (_) => const MainMenuScreen(),
        '/levels': (_) => const LevelSelectScreen(),
        '/game': (_) => const GameScreen(),
        '/game_over': (_) => const GameOverScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
