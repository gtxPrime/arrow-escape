import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/maze_background.dart';
import '../../core/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();

    // Animate the progress bar over the full splash duration
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    // Drive the bar with an ease-in-out curve for a natural feel
    _progressController.forward();

    // Navigate when done
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/menu');
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                return Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: BlendedMazeBackground(
                    height: 380,
                    progress: _progressController.value,
                  ),
                );
              },
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Arrow icons
                  _ArrowsBackground(),
              const SizedBox(height: 32),

              // Logo
              _buildLogo(),

              const SizedBox(height: 16),

              // Tagline
              Text(
                'Slide. Clear. Conquer.',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              )
                  .animate(delay: 600.ms)
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: 0.3, end: 0),

              const SizedBox(height: 52),

              // ── Animated progress bar ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, _) {
                        // Ease the fill for a more natural loading feel
                        final progress = CurvedAnimation(
                          parent: _progressController,
                          curve: Curves.easeInOut,
                        ).value;

                        return Column(
                          children: [
                            // Progress bar track
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                height: 4,
                                width: double.infinity,
                                color: AppColors.primary.withValues(alpha: 0.15),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: progress,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.primary.withValues(alpha: 0.7),
                                            AppColors.primary,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(alpha: 0.4),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Status label that changes with progress
                            Text(
                              progress < 0.5
                                  ? 'Loading assets…'
                                  : progress < 0.9
                                      ? 'Generating levels…'
                                      : 'Almost ready…',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: AppColors.textSecondary.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ).animate(delay: 800.ms).fadeIn(duration: 500.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Text(
          'ARROW OUT',
          style: GoogleFonts.nunito(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: 4,
            shadows: [
              Shadow(
                color: AppColors.accentGold.withValues(alpha: 0.15),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        )
            .animate(delay: 300.ms)
            .fadeIn(duration: 500.ms)
            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
      ],
    );
  }
}

class _ArrowsBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
