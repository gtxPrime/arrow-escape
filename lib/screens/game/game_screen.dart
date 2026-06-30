import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';

import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../data/models/arrow.dart';
import '../../data/models/level.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/level_repository.dart';
import '../../ads/ad_manager.dart';
import '../../game/arrow_puzzle_game.dart';
import '../../game/game_state.dart';
import '../../widgets/lives_bar.dart';
import '../../widgets/wavy_progress_bar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late LevelModel _level;
  late ArrowPuzzleGame _game;
  GameState? _gameState;
  late ConfettiController _confettiController;
  bool _showingGameOver = false;
  bool _showingComplete = false;
  int _lives = AppConstants.maxLives;
  int? _loadedLevelNum;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final levelNum = args?['level'] as int? ?? 1;
    if (_loadedLevelNum != levelNum) {
      _loadedLevelNum = levelNum;
      final levelRepo = context.read<LevelRepository>();
      _level = levelRepo.getLevel(levelNum);
      _initGame();
      // Pre-generate next levels
      levelRepo.preGenerate(levelNum + 1, 5);
    }
  }

  void _initGame() {
    _lives = AppConstants.maxLives;
    _showingGameOver = false;
    _showingComplete = false;

    _gameState?.removeListener(_onGameStateChanged);
    _gameState = GameState(
      level: _level,
      onLevelComplete: _onLevelComplete,
      onGameOver: _onGameOver,
      onLifeLost: _onLifeLost,
    );
    _gameState!.addListener(_onGameStateChanged);

    _game = ArrowPuzzleGame(
      level: _level,
      gameState: _gameState!,
      onLevelComplete: _onLevelComplete,
      onGameOver: _onGameOver,
      onLifeLost: _onLifeLost,
    );
  }

  void _onGameStateChanged() {
    if (!mounted) return;
    setState(() {
      _lives = _gameState!.lives;
    });
  }

  void _onLifeLost() {
    if (!mounted) return;
    setState(() => _lives = _gameState!.lives);
    if (context.read<ProgressRepository>().vibrationEnabled) {
      HapticFeedback.heavyImpact();
    }
  }

  void _onLevelComplete() {
    if (!mounted || _showingComplete) return;
    setState(() => _showingComplete = true);
    _confettiController.play();
    if (context.read<ProgressRepository>().vibrationEnabled) {
      HapticFeedback.lightImpact();
    }

    final progress = context.read<ProgressRepository>();
    final adManager = context.read<AdManager>();
    final stars = ProgressRepository.calculateStars(
        _gameState!.livesLost, _level.totalArrows, _gameState!.movesUsed);
    final score =
        AppConstants.baseScore + (_lives * AppConstants.bonusPerRemainingLife);

    progress.recordLevelComplete(LevelResult(
      levelNumber: _level.levelNumber,
      stars: stars,
      score: score,
      movesUsed: _gameState!.movesUsed,
      livesLost: _gameState!.livesLost,
      completed: true,
      completedAt: DateTime.now(),
    ));

    final levelType = AppConstants.levelTypeFor(_level.levelNumber);
    adManager.onLevelComplete(_level.levelNumber, levelType.isSpecial);

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _showLevelCompleteDialog(stars, score);
    });
  }

  void _onGameOver() {
    if (!mounted || _showingGameOver) return;
    setState(() => _showingGameOver = true);
    if (context.read<ProgressRepository>().vibrationEnabled) {
      HapticFeedback.vibrate();
    }
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _showGameOverDialog();
    });
  }

  Future<void> _showSettingsDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _GameSettingsDialog(
        onRestart: () {
          Navigator.pop(context);
          setState(() {
            _showingGameOver = false;
            _game.resetLevel();
            _lives = AppConstants.maxLives;
          });
        },
      ),
    );
  }

  Future<void> _showLevelCompleteDialog(int stars, int score) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LevelCompleteDialog(
        level: _level,
        stars: stars,
        score: score,
        onNextLevel: () {
          Navigator.pop(context);
          Navigator.pushReplacementNamed(
            context,
            '/game',
            arguments: {'level': _level.levelNumber + 1},
          );
        },
        onMenu: () {
          Navigator.pop(context);
          Navigator.pushReplacementNamed(context, '/menu');
        },
        onDoubleCoins: () {
          final adManager = context.read<AdManager>();
          adManager.showRewarded(
            onRewarded: () {
              context.read<ProgressRepository>().addCoins(score ~/ 10);
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/game',
                  arguments: {'level': _level.levelNumber + 1});
            },
            onDismissed: () => Navigator.pop(context),
          );
        },
      ),
    );
  }

  Future<void> _showGameOverDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GameOverDialog(
        level: _level,
        onContinue: () {
          // Watch rewarded ad to restore 1 life
          final adManager = context.read<AdManager>();
          Navigator.pop(context);
          adManager.showRewarded(
            onRewarded: () {
              setState(() {
                _showingGameOver = false;
                _gameState!.restoreLife();
                _lives = _gameState!.lives;
              });
            },
            onDismissed: () {},
          );
        },
        onRestart: () {
          Navigator.pop(context);
          setState(() {
            _showingGameOver = false;
            _game.resetLevel();
            _lives = AppConstants.maxLives;
          });
        },
        onMenu: () {
          Navigator.pop(context);
          Navigator.pushReplacementNamed(context, '/menu');
        },
      ),
    );
  }

  @override
  void dispose() {
    _gameState?.removeListener(_onGameStateChanged);
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final levelType = AppConstants.levelTypeFor(_level.levelNumber);
    final adManager = context.read<AdManager>();

    // Calculate level progress
    final totalArrows = _level.arrows.length;
    final activeArrows =
        _gameState?.arrows.where((a) => a.state != ArrowState.sliding).length ??
            totalArrows;
    final clearedArrows = totalArrows - activeArrows;
    final progressVal =
        totalArrows > 0 ? (clearedArrows / totalArrows).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top Bar ─────────────────────────────────────────────────
              _TopBar(
                level: _level,
                levelType: levelType,
                lives: _lives,
                progress: progressVal,
                onBack: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, '/menu');
                  }
                },
                onSettings: _showSettingsDialog,
              ),

              // ── Game Canvas ──────────────────────────────────────────────
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Measure the real screen area BEFORE entering InteractiveViewer
                    // (InteractiveViewer gives unbounded constraints to its children,
                    // so LayoutBuilder must be OUTSIDE to get finite values).
                    final boardSize =
                        min(constraints.maxWidth, constraints.maxHeight - 16);
                    return Stack(
                      children: [
                        // InteractiveViewer now fills the full Expanded area,
                        // making pinch-zoom work anywhere on screen.
                        InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 4.0,
                          boundaryMargin: const EdgeInsets.all(60),
                          clipBehavior: Clip.hardEdge,
                          child: Center(
                            child: SizedBox(
                              width: boardSize,
                              height: boardSize,
                              child: GameWidget(game: _game),
                            ),
                          ),
                        ),

                        // Confetti on level complete
                        Align(
                          alignment: Alignment.topCenter,
                          child: ConfettiWidget(
                            confettiController: _confettiController,
                            blastDirectionality: BlastDirectionality.explosive,
                            shouldLoop: false,
                            colors: const [
                              AppColors.primary,
                              AppColors.accentGold,
                              AppColors.accentGreen,
                              AppColors.accent,
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // ── Banner Ad (centered and sized to avoid layout warnings) ──
              if (adManager.bannerAd != null)
                Container(
                  alignment: Alignment.center,
                  width: double.infinity,
                  height: 50,
                  child: SizedBox(
                    width: 320,
                    height: 50,
                    child: AdWidget(
                      key: UniqueKey(),
                      ad: adManager.bannerAd!,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Top Bar ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final LevelModel level;
  final LevelType levelType;
  final int lives;
  final double progress;
  final VoidCallback onBack;
  final VoidCallback onSettings;

  const _TopBar({
    required this.level,
    required this.levelType,
    required this.lives,
    required this.progress,
    required this.onBack,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Left Side (Back Button aligned left)
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.arrowLeft,
                    color: AppColors.textPrimary, size: 18),
              ),
            ),
          ),

          // Center Side (Level Label & Progress Bar, perfectly centered)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (levelType.isSpecial)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      margin: const EdgeInsets.bottom(4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (levelType == LevelType.god
                                ? AppColors.accent
                                : AppColors.accentOrange)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            levelType == LevelType.god
                                ? LucideIcons.flame
                                : LucideIcons.zap,
                            color: levelType == LevelType.god
                                ? AppColors.accent
                                : AppColors.accentOrange,
                            size: 10,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            levelType.label.toUpperCase(),
                            style: GoogleFonts.nunito(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: levelType == LevelType.god
                                  ? AppColors.accent
                                  : AppColors.accentOrange,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Level ${level.levelNumber}',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                // Level progress bar with horizontal wavy liquid animation (width adjusted to 80 to prevent overlaps)
                WavyProgressBar(
                  progress: progress,
                  width: 80,
                  height: 9.0,
                ),
              ],
            ),
          ),

          // Right Side (LivesBar & Settings aligned right)
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LivesBar(lives: lives, maxLives: AppConstants.maxLives),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onSettings,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.settings,
                        color: AppColors.textPrimary, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Level Complete Dialog ─────────────────────────────────────────────────────

class _LevelCompleteDialog extends StatelessWidget {
  final LevelModel level;
  final int stars;
  final int score;
  final VoidCallback onNextLevel;
  final VoidCallback onMenu;
  final VoidCallback onDoubleCoins;

  const _LevelCompleteDialog({
    required this.level,
    required this.stars,
    required this.score,
    required this.onNextLevel,
    required this.onMenu,
    required this.onDoubleCoins,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 32),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)).animate().scale(
                begin: const Offset(0, 0),
                end: const Offset(1, 1),
                duration: 400.ms,
                curve: Curves.elasticOut),
            const SizedBox(height: 8),
            Text('Level Complete!',
                style: GoogleFonts.nunito(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),

            // Stars
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  3,
                  (i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(i < stars ? '⭐' : '☆',
                            style: const TextStyle(fontSize: 32)),
                      )
                          .animate(delay: Duration(milliseconds: 200 + i * 150))
                          .scale(
                              begin: const Offset(0, 0),
                              end: const Offset(1, 1),
                              curve: Curves.elasticOut)),
            ),
            const SizedBox(height: 20),

            // Score
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.accentGold.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text('+$score',
                      style: GoogleFonts.nunito(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentGold)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Next Level button
            _DialogButton(
              label: 'Next Level',
              icon: Icons.play_arrow_rounded,
              gradient: AppColors.primaryGradient,
              onTap: onNextLevel,
            ),
            const SizedBox(height: 10),

            // Double coins (rewarded ad)
            _DialogButton(
              label: '🎬 Double Coins',
              icon: Icons.add_circle_outline,
              gradient: const LinearGradient(
                  colors: [Color(0xFF856404), Color(0xFFCC9A06)]),
              onTap: onDoubleCoins,
            ),
            const SizedBox(height: 10),

            TextButton(
              onPressed: onMenu,
              child: Text('Back to Menu',
                  style: GoogleFonts.nunito(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Game Over Dialog ──────────────────────────────────────────────────────────

class _GameOverDialog extends StatelessWidget {
  final LevelModel level;
  final VoidCallback onContinue;
  final VoidCallback onRestart;
  final VoidCallback onMenu;

  const _GameOverDialog({
    required this.level,
    required this.onContinue,
    required this.onRestart,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.2), blurRadius: 32),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Icon(
               LucideIcons.heartOff,
               color: AppColors.accent,
               size: 52,
             ).animate().shake(duration: 500.ms),
             const SizedBox(height: 12),
            Text('Out of Lives!',
                style: GoogleFonts.nunito(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('Watch an ad to get 1 more life and continue',
                style: GoogleFonts.nunito(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 28),

            // Continue with ad
            _DialogButton(
              label: 'Get 1 More Life & Continue',
              icon: LucideIcons.clapperboard,
              gradient: AppColors.successGradient,
              onTap: onContinue,
            ),
            const SizedBox(height: 10),

            // Restart (all lives back)
            _DialogButton(
              label: 'Restart Level',
              icon: Icons.refresh_rounded,
              gradient: const LinearGradient(
                  colors: [Color(0xFF252545), Color(0xFF1A1A2E)]),
              onTap: onRestart,
            ),
            const SizedBox(height: 10),

            TextButton(
              onPressed: onMenu,
              child: Text('Main Menu',
                  style: GoogleFonts.nunito(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _DialogButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameSettingsDialog extends StatelessWidget {
  final VoidCallback onRestart;

  const _GameSettingsDialog({required this.onRestart});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressRepository>();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.surfaceLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Settings',
              style: GoogleFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // Sound Toggle
            _DialogSettingsTile(
              icon: LucideIcons.volume2,
              label: 'Sound Effects',
              value: progress.soundEnabled,
              onChanged: (val) => progress.setSoundEnabled(val),
            ),

            // Music Toggle
            _DialogSettingsTile(
              icon: LucideIcons.music,
              label: 'Background Music',
              value: progress.musicEnabled,
              onChanged: (val) => progress.setMusicEnabled(val),
            ),

            // Vibration Toggle
            _DialogSettingsTile(
              icon: LucideIcons.vibrate,
              label: 'Vibration',
              value: progress.vibrationEnabled,
              onChanged: (val) => progress.setVibrationEnabled(val),
            ),

            const SizedBox(height: 16),
            const Divider(color: AppColors.surfaceLight, height: 1),
            const SizedBox(height: 20),

            // Restart Button
            _DialogButton(
              label: 'Restart Level',
              icon: LucideIcons.rotateCcw,
              gradient: const LinearGradient(
                colors: [Color(0xFF252545), Color(0xFF1A1A2E)],
              ),
              onTap: onRestart,
            ),
            const SizedBox(height: 10),

            // Close / Resume Button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Resume Game',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogSettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _DialogSettingsTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
