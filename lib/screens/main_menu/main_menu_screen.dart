import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/level_repository.dart';
import '../../data/models/level.dart';
import '../../data/models/arrow.dart';
import '../../widgets/arrow_line.dart';
import '../../ads/ad_manager.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  bool _isNavigating = false; // prevents double-tap and shows instant feedback

  @override
  void initState() {
    super.initState();
    // Record daily play + pre-warm current level in background after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProgressRepository>().recordDailyPlay();
      _preWarmLevels();
    });
  }

  /// Pre-generate the current level and next 3 in background isolates so that
  /// tapping Play opens the game screen instantly with no UI-thread jank.
  void _preWarmLevels() {
    final progress = context.read<ProgressRepository>();
    final levelRepo = context.read<LevelRepository>();
    final currentLevel = progress.currentLevel;
    // Pre-warm current + next 3 levels in background isolates (non-blocking)
    for (int i = 0; i < 4; i++) {
      levelRepo.preGenerateAsync(currentLevel + i);
    }
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
    final adManager = context.read<AdManager>();

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
                    // Coins counter (replaced water drops with coins icon)
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.coins,
                          color: Color(0xFFF1C40F), // Premium gold coin color
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

                    // Top Bar Actions
                    Row(
                      children: [
                        // Level Select grid icon
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/levels'),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              LucideIcons.layoutGrid,
                              color: AppColors.textPrimary,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

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
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // ── Center Title "ARROW OUT" with Premium Floating Icons ──
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ArrowLine(direction: ArrowDirection.left, color: AppColors.arrowLeft, size: 52, strokeWidth: 6)
                          .animate(onPlay: (controller) => controller.repeat(reverse: true))
                          .slideY(begin: 0, end: -0.15, duration: 1200.ms, curve: Curves.easeInOut),
                      ArrowLine(direction: ArrowDirection.up, color: AppColors.arrowUp, size: 52, strokeWidth: 6)
                          .animate(onPlay: (controller) => controller.repeat(reverse: true))
                          .slideY(begin: 0, end: -0.15, duration: 1200.ms, curve: Curves.easeInOut, delay: 200.ms),
                      ArrowLine(direction: ArrowDirection.right, color: AppColors.arrowRight, size: 52, strokeWidth: 6)
                          .animate(onPlay: (controller) => controller.repeat(reverse: true))
                          .slideY(begin: 0, end: -0.15, duration: 1200.ms, curve: Curves.easeInOut, delay: 400.ms),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'ARROW OUT',
                    style: GoogleFonts.nunito(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: 3,
                      shadows: [
                        Shadow(
                          color: AppColors.primary.withValues(alpha: 0.8),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                  ).animate().scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1.0, 1.0),
                      duration: 500.ms,
                      curve: Curves.elasticOut),
                ],
              ),

              const Spacer(flex: 2),

              // ── Level Slider / Timeline ───────────────────────────────────
              _buildLevelTimeline(progress.currentLevel),

              const SizedBox(height: 36),

              // ── Big Play Button ───────────────────────────────────────────
              _buildBigPlayButton(context, progress),

              const Spacer(flex: 3),

              // ── Banner Ad ──────────────────────────────────────────────────
              if (adManager.homeBannerAd != null)
                Container(
                  alignment: Alignment.center,
                  width: double.infinity,
                  height: 50,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: 320,
                    height: 50,
                    child: AdWidget(
                      key: const ValueKey('home_banner_ad'),
                      ad: adManager.homeBannerAd!,
                    ),
                  ),
                ),
            ],
          ),
        ),
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
            double size = isCurrent ? 46.0 : 34.0;
            final type = AppConstants.levelTypeFor(lvl);

            if (type == LevelType.god) {
              bubbleColor = const Color(0xFFB33939); // Red for God levels
              textColor = Colors.white;
            } else if (type == LevelType.boss) {
              bubbleColor = const Color(0xFF8E44AD); // Purple for Boss levels
              textColor = Colors.white;
            } else {
              bubbleColor = isCurrent ? const Color(0xFFC08255) : const Color(0xFFE6DCC8); // Normal colors (Gold-brown if active current, warm beige otherwise)
              textColor = isCurrent ? Colors.white : const Color(0xFF8B7365);
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: bubbleColor,
                shape: BoxShape.circle,
                border: isCurrent
                    ? Border.all(color: Colors.white, width: 3)
                    : null,
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: bubbleColor.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 3,
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
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: GestureDetector(
        onTap: _isNavigating
            ? null
            : () async {
                if (!mounted) return;
                setState(() => _isNavigating = true);
                await Navigator.pushNamed(
                  context,
                  '/game',
                  arguments: {'level': progress.currentLevel},
                );
                if (mounted) setState(() => _isNavigating = false);
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isNavigating
                  ? [const Color(0xFF8B1A1A), const Color(0xFF6E1515)]
                  : [const Color(0xFFE74C3C), const Color(0xFFC0392B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC0392B).withValues(alpha: _isNavigating ? 0.15 : 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isNavigating)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(
                  LucideIcons.play,
                  color: Colors.white,
                  size: 26,
                ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isNavigating ? 'LOADING…' : 'PLAY NOW',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                  Text(
                    'Level ${progress.currentLevel} • $diffLabel',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ).animate(onPlay: (controller) => controller.repeat(reverse: true))
       .scale(
         begin: const Offset(1.0, 1.0),
         end: const Offset(1.02, 1.02),
         duration: 1.2.seconds,
         curve: Curves.easeInOut,
       ),
    );
  }
}
