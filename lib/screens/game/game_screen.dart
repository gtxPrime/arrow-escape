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
  bool _isLoadingLevel = false; // true while level is being generated async

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
      _loadLevelAsync(levelNum);
    }
  }

  Future<void> _loadLevelAsync(int levelNum) async {
    final levelRepo = context.read<LevelRepository>();

    // If level is already cached, load it instantly with no spinner.
    if (levelRepo.isCached(levelNum)) {
      _level = levelRepo.getLevel(levelNum);
      _initGame();
      // Pre-warm next levels off the UI thread
      levelRepo.preGenerateRangeAsync(levelNum + 1, 5);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showTutorialDialogIfNeeded(levelNum);
      });
      return;
    }

    // Level not cached — show loading overlay and generate in background isolate
    if (mounted) setState(() => _isLoadingLevel = true);

    try {
      final level = await levelRepo.getLevelAsync(levelNum);
      if (!mounted) return;
      _level = level;
      _initGame();
      setState(() => _isLoadingLevel = false);

      // Pre-warm next levels off the UI thread
      levelRepo.preGenerateRangeAsync(levelNum + 1, 5);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showTutorialDialogIfNeeded(levelNum);
      });
    } catch (_) {
      // Fallback: generate synchronously if async fails
      if (!mounted) return;
      _level = levelRepo.getLevel(levelNum);
      _initGame();
      if (mounted) setState(() => _isLoadingLevel = false);
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
    // Show a premium loading screen while the level is being generated
    // in the background isolate — no freeze, no blank screen.
    if (_isLoadingLevel || !_isLevelReady) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final levelNum = args?['level'] as int? ?? 1;
      return _LevelLoadingScreen(levelNumber: levelNum);
    }

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

  bool get _isLevelReady => _gameState != null;

  void _showTutorialDialogIfNeeded(int levelNum) {
    if (levelNum == 2) {
      _showTutorialDialog(
        title: 'Color Paired Arrows',
        description: 'Arrows with matching colors are paired together! Tap on either arrow in the pair, and both will slide out together simultaneously. Make sure both exit paths are clear!',
        icon: LucideIcons.coins,
        iconColor: const Color(0xFFFF2D55),
        animationWidget: _buildColorLockAnimation(),
      );
    } else if (levelNum == 3) {
      _showTutorialDialog(
        title: 'Deflector Dots',
        description: 'Gold deflector dots change the direction of exiting arrows! Trace the exit path through the deflector dots to make sure the arrow escapes successfully.',
        icon: LucideIcons.rotateCw,
        iconColor: const Color(0xFFFFAA00),
        animationWidget: _buildDeflectorAnimation(),
      );
    }
  }

  void _showTutorialDialog({
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required Widget animationWidget,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                animationWidget,
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Start Tutorial',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorLockAnimation() {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // First paired arrow
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2D55).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF2D55), width: 1.5),
              ),
              child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFFFF2D55), size: 18),
            ).animate(onPlay: (c) => c.repeat())
             .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.03, 1.03), duration: 800.ms, curve: Curves.easeInOut)
             .slideY(begin: 0, end: -1.2, delay: 1000.ms, duration: 600.ms)
             .fadeOut(delay: 1000.ms, duration: 200.ms),

            const SizedBox(width: 32),

            // Second paired arrow (exits at the same time!)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2D55).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF2D55), width: 1.5),
              ),
              child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFFFF2D55), size: 18),
            ).animate(onPlay: (c) => c.repeat())
             .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.03, 1.03), duration: 800.ms, curve: Curves.easeInOut)
             .slideY(begin: 0, end: -1.2, delay: 1000.ms, duration: 600.ms)
             .fadeOut(delay: 1000.ms, duration: 200.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildDeflectorAnimation() {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFFAA00),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFAA00).withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          Positioned(
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ).animate(onPlay: (c) => c.repeat())
             .custom(
               duration: 1.2.seconds,
               builder: (context, val, child) {
                 double dx = 0;
                 double dy = 0;
                 if (val < 0.5) {
                   dx = 60 * (1 - val * 2);
                   dy = 0;
                 } else {
                   dx = 0;
                   dy = -60 * ((val - 0.5) * 2);
                 }
                 return Transform.translate(
                   offset: Offset(dx, dy),
                   child: child,
                 );
               },
             ),
          ),
        ],
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
      height: 115,
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

          // Center Side (Level Label, Progress Bar & Lives, perfectly centered)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (levelType.isSpecial)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
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
                // Level progress bar with horizontal wavy liquid animation (width adjusted to 130, height to 10.0)
                WavyProgressBar(
                  progress: progress,
                  width: 130,
                  height: 10.0,
                ),
                const SizedBox(height: 6),
                // Lives bar centered below the progress bar
                LivesBar(lives: lives, maxLives: AppConstants.maxLives),
              ],
            ),
          ),

          // Right Side (Settings Button aligned right)
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
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

// ── Premium level loading screen ──────────────────────────────────────────────
/// Shown while the level is being generated in a background isolate.
/// Users see animated arrows and a loading indicator instead of a frozen UI.
class _LevelLoadingScreen extends StatefulWidget {
  final int levelNumber;
  const _LevelLoadingScreen({required this.levelNumber});

  @override
  State<_LevelLoadingScreen> createState() => _LevelLoadingScreenState();
}

class _LevelLoadingScreenState extends State<_LevelLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulsing arrow cluster
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Transform.scale(
                  scale: 0.88 + 0.12 * _pulse.value,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _miniArrow('←', AppColors.arrowLeft),
                      const SizedBox(width: 8),
                      _miniArrow('↑', AppColors.arrowUp),
                      const SizedBox(width: 8),
                      _miniArrow('→', AppColors.arrowRight),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Level number
              Text(
                'LEVEL ${widget.levelNumber}',
                style: GoogleFonts.nunito(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Generating puzzle…',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 32),

              // Animated dots
              _BouncingDots(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniArrow(String symbol, Color color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 10),
        ],
      ),
      child: Center(
        child: Text(symbol, style: TextStyle(fontSize: 24, color: color)),
      ),
    );
  }
}

/// Three bouncing dots loader used inside the loading screen.
class _BouncingDots extends StatefulWidget {
  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final phase = (_ctrl.value + i * 0.33) % 1.0;
            final offset = -8.0 * (1 - (phase * 2 - 1).abs()).clamp(0.0, 1.0);
            return Transform.translate(
              offset: Offset(0, offset),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.6 + 0.4 * (1 - (phase * 2 - 1).abs()).clamp(0.0, 1.0)),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

