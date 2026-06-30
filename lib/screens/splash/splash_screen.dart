import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
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
        child: Center(
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
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        // Arrow icon cluster
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ArrowIcon(direction: '←', color: AppColors.arrowLeft, delay: 0),
            _ArrowIcon(direction: '↑', color: AppColors.arrowUp, delay: 100),
            _ArrowIcon(direction: '→', color: AppColors.arrowRight, delay: 200),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'ARROW OUT',
          style: GoogleFonts.nunito(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: 4,
            shadows: [
              Shadow(
                color: AppColors.primary.withValues(alpha: 0.8),
                blurRadius: 24,
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

class _ArrowIcon extends StatelessWidget {
  final String direction;
  final Color color;
  final int delay;

  const _ArrowIcon(
      {required this.direction, required this.color, required this.delay});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12)
        ],
      ),
      child: Center(
        child: Text(
          direction,
          style: TextStyle(fontSize: 26, color: color),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: delay))
        .fadeIn(duration: 400.ms)
        .scale(
            begin: const Offset(0, 0),
            end: const Offset(1, 1),
            curve: Curves.elasticOut);
  }
}

class _ArrowsBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
