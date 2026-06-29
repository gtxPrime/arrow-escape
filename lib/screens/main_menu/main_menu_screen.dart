import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/models/level.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  @override
  void initState() {
    super.initState();
    // Record daily play for streak
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProgressRepository>().recordDailyPlay();
    });
  }

  String _getDifficultyLabel(int levelNum) {
    final type = AppConstants.levelTypeFor(levelNum);
    if (type == LevelType.god) return 'Super Hard';
    if (type == LevelType.boss) return 'Hard';
    final difficulty = Difficulty.forLevel(levelNum);
    return difficulty.label;
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressRepository>();
    final dateStr = DateFormat('MMM d').format(DateTime.now());

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top Bar ───────────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Droplets counter
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.droplets,
                          color: Color(0xFF3498DB),
                          size: 22,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${progress.coins}',
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    // Settings icon
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/settings'),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.settings_outlined,
                          color: AppColors.textPrimary,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── Challenge & Event Cards ───────────────────────────────────
              _buildCards(dateStr),

              const Spacer(),

              // ── Center Title "Amaze GO!" ───────────────────────────────────
              Text(
                'Amaze GO!',
                style: GoogleFonts.nunito(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: 1.5,
                ),
              ).animate().scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1.0, 1.0),
                  duration: 500.ms,
                  curve: Curves.elasticOut),

              const Spacer(),

              // ── Level Slider / Timeline ───────────────────────────────────
              _buildLevelTimeline(progress.currentLevel),

              const SizedBox(height: 24),

              // ── Big Play Button ───────────────────────────────────────────
              _buildBigPlayButton(context, progress),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCards(String dateStr) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Daily Challenge Card
          Expanded(
            child: Container(
              height: 190,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD65C47), Color(0xFFB33939)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB33939).withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Challenge',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  Text(
                    dateStr,
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  const Center(
                    child: Icon(
                      LucideIcons.trophy,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'Start',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFB33939),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Event Card
          Expanded(
            child: Container(
              height: 190,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF82C059), Color(0xFF4A8C34)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A8C34).withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Event',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  Text(
                    'Spring Battle',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.bug, size: 28, color: Colors.white.withValues(alpha: 0.85)),
                        const SizedBox(width: 4),
                        const Icon(LucideIcons.bug, size: 36, color: Colors.white),
                        const SizedBox(width: 4),
                        Icon(LucideIcons.bug, size: 28, color: Colors.white.withValues(alpha: 0.85)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'Play',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF4A8C34),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelTimeline(int currentLevel) {
    final levelRange = List.generate(5, (index) => currentLevel - 2 + index);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Connecting line behind bubbles
        Container(
          width: 250,
          height: 4,
          color: const Color(0xFFE5DEC9),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: levelRange.map((lvl) {
            if (lvl <= 0) return const SizedBox(width: 48);

            final isCurrent = lvl == currentLevel;

            Color bubbleColor;
            Color textColor;
            double size;

            if (isCurrent) {
              bubbleColor =
                  const Color(0xFFB33939); // Red highlighting current level
              textColor = Colors.white;
              size = 46.0;
            } else {
              final type = AppConstants.levelTypeFor(lvl);
              if (type == LevelType.god) {
                bubbleColor = const Color(0xFFB33939).withValues(alpha: 0.8);
                textColor = Colors.white;
              } else if (type == LevelType.boss) {
                bubbleColor = const Color(0xFF8E44AD); // Purple for Boss
                textColor = Colors.white;
              } else {
                bubbleColor = const Color(0xFFE6DCC8); // Warm beige for normal
                textColor = const Color(0xFF8B7365);
              }
              size = 34.0;
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: bubbleColor,
                shape: BoxShape.circle,
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: bubbleColor.withValues(alpha: 0.4),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  '$lvl',
                  style: GoogleFonts.nunito(
                    fontSize: isCurrent ? 18 : 14,
                    fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBigPlayButton(
      BuildContext context, ProgressRepository progress) {
    final diffLabel = _getDifficultyLabel(progress.currentLevel);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(
          context,
          '/game',
          arguments: {'level': progress.currentLevel},
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFFB33939),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB33939).withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                diffLabel,
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                'Level ${progress.currentLevel}',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
