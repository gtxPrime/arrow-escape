import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';


import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../data/repositories/progress_repository.dart';
import '../../core/audio_manager.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressRepository>();
    const totalVisible = 500; // Show first 500 levels

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        AudioManager.instance.playClick();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppColors.textPrimary, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('Select Level',
                        style: GoogleFonts.nunito(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                  ],
                ),
              ),

              // Grid
              Expanded(
                child: GridView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: totalVisible,
                  itemBuilder: (context, index) {
                    final levelNum = index + 1;
                    final isUnlocked = progress.isLevelUnlocked(levelNum);
                    final stars = progress.getStarsForLevel(levelNum);
                    final levelType = AppConstants.levelTypeFor(levelNum);

                    return _LevelCell(
                      levelNumber: levelNum,
                      isUnlocked: isUnlocked,
                      stars: stars,
                      levelType: levelType,
                      onTap: isUnlocked
                          ? () {
                              AudioManager.instance.playClick();
                              Navigator.pushReplacementNamed(
                                context,
                                '/game',
                                arguments: {'level': levelNum},
                              );
                            }
                          : null,
                    )
                        .animate(
                            delay: Duration(milliseconds: (index % 20) * 20))
                        .fadeIn(duration: 200.ms)
                        .scale(
                            begin: const Offset(0.7, 0.7),
                            end: const Offset(1, 1));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelCell extends StatelessWidget {
  final int levelNumber;
  final bool isUnlocked;
  final int stars;
  final LevelType levelType;
  final VoidCallback? onTap;

  const _LevelCell({
    required this.levelNumber,
    required this.isUnlocked,
    required this.stars,
    required this.levelType,
    required this.onTap,
  });

  Color get _borderColor {
    if (!isUnlocked) return AppColors.surfaceLight;
    switch (levelType) {
      case LevelType.god:
        return AppColors.accent; // Red
      case LevelType.boss:
        return const Color(0xFF8E44AD); // Purple for Boss level
      case LevelType.tutorial:
        return AppColors.accentGreen; // Green
      case LevelType.normal:
        return AppColors.primary.withValues(alpha: 0.4);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isUnlocked ? AppColors.surface : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor, width: 1.5),
          boxShadow: isUnlocked && levelType.isSpecial
              ? [
                  BoxShadow(
                    color: _borderColor.withValues(alpha: 0.35),
                    blurRadius: 10,
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Level type badge
            if (levelType == LevelType.god)
              Icon(LucideIcons.flame, color: AppColors.accent, size: 12)
            else if (levelType == LevelType.boss)
              const Icon(LucideIcons.zap, color: Color(0xFF8E44AD), size: 12)
            else if (levelType == LevelType.tutorial)
              Icon(LucideIcons.bookOpen, color: AppColors.accentGreen, size: 12),

            // Lock or number
            if (!isUnlocked)
              Icon(Icons.lock_outline_rounded,
                  color: AppColors.textMuted, size: 20)
            else
              Text('$levelNumber',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  )),

            // Stars
            if (isUnlocked && stars > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    3,
                    (i) => Text(
                          i < stars ? '⭐' : '·',
                          style: TextStyle(
                            fontSize: i < stars ? 8 : 10,
                            color: i < stars
                                ? AppColors.starYellow
                                : AppColors.textMuted,
                          ),
                        )),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
