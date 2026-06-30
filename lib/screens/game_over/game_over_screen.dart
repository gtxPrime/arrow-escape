import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/app_colors.dart';
import '../../ads/ad_manager.dart';

/// Full-screen game over overlay (alternative to dialog — used as a route).
class GameOverScreen extends StatelessWidget {
  const GameOverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final levelNumber = args?['level'] as int? ?? 1;
    final adManager = context.read<AdManager>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Broken heart
                const Icon(
                  LucideIcons.heartOff,
                  size: 80,
                  color: Color(0xFFE74C3C),
                )
                    .animate()
                    .shake(duration: 600.ms)
                    .then()
                    .fadeIn(),

                const SizedBox(height: 24),

                Text(
                  'Out of Lives!',
                  style: GoogleFonts.nunito(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.3),

                const SizedBox(height: 8),

                Text(
                  'Level $levelNumber',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ).animate(delay: 300.ms).fadeIn(),

                const SizedBox(height: 40),

                // Lives display (all empty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                      3,
                      (_) => const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Opacity(
                              opacity: 0.22,
                              child: Icon(
                                Icons.favorite,
                                color: Color(0xFFFF2D55), // Solid pinkish red heart
                                size: 32,
                              ),
                            ),
                          )),
                ).animate(delay: 400.ms).fadeIn(),

                const SizedBox(height: 48),

                _ActionButton(
                  icon: LucideIcons.clapperboard,
                  label: 'Get 1 More Life & Continue',
                  subtitle: 'Watch an ad to get 1 more life',
                  gradient: AppColors.successGradient,
                  onTap: () {
                    adManager.showRewarded(
                      onRewarded: () {
                        Navigator.pushReplacementNamed(context, '/game',
                            arguments: {'level': levelNumber, 'revived': true});
                      },
                    );
                  },
                ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.3),

                const SizedBox(height: 14),

                // Restart level (full lives)
                _ActionButton(
                  icon: LucideIcons.rotateCcw,
                  label: 'Restart Level',
                  subtitle: 'Start over with 3 lives',
                  gradient: const LinearGradient(
                      colors: [AppColors.surfaceLight, AppColors.surface]),
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/game',
                        arguments: {'level': levelNumber});
                  },
                ).animate(delay: 600.ms).fadeIn().slideY(begin: 0.3),

                const SizedBox(height: 14),

                // Back to menu
                TextButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/menu'),
                  child: Text('Main Menu',
                      style: GoogleFonts.nunito(
                          color: AppColors.textSecondary, fontSize: 16)),
                ).animate(delay: 700.ms).fadeIn(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: Colors.white),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                Text(subtitle,
                    style: GoogleFonts.nunito(
                        fontSize: 12, color: Colors.white60)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
