import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../data/repositories/progress_repository.dart';
import '../../core/audio_manager.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressRepository>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
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
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppColors.textPrimary, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('Settings',
                        style: GoogleFonts.nunito(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.volume_up_outlined,
                        label: 'Sound Effects',
                        trailing: Switch(
                          value: progress.soundEnabled,
                          onChanged: (val) {
                            AudioManager.instance.playClick();
                            progress.setSoundEnabled(val);
                          },
                          activeThumbColor: AppColors.primary,
                        ),
                      ),
                      _SettingsTile(
                        icon: Icons.music_note_outlined,
                        label: 'Background Music',
                        trailing: Switch(
                          value: progress.musicEnabled,
                          onChanged: (val) {
                            AudioManager.instance.playClick();
                            progress.setMusicEnabled(val);
                          },
                          activeThumbColor: AppColors.primary,
                        ),
                      ),
                      _SettingsTile(
                        icon: Icons.vibration_rounded,
                        label: 'Haptic Feedback',
                        trailing: Switch(
                          value: progress.vibrationEnabled,
                          onChanged: (val) {
                            AudioManager.instance.playClick();
                            progress.setVibrationEnabled(val);
                          },
                          activeThumbColor: AppColors.primary,
                        ),
                      ),
                      const Divider(color: AppColors.surfaceLight, height: 32),
                      _SettingsTile(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privacy Policy',
                        trailing: const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textSecondary),
                        onTap: () {},
                      ),
                      _SettingsTile(
                        icon: Icons.star_outline_rounded,
                        label: 'Rate the App',
                        trailing: const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textSecondary),
                        onTap: () {},
                      ),
                      const Spacer(),
                      Text('Arrow Out v1.0.0',
                          style: GoogleFonts.nunito(
                              color: AppColors.textMuted, fontSize: 12)),
                      Text('com.gxdevs.arrowout',
                          style: GoogleFonts.nunito(
                              color: AppColors.textMuted, fontSize: 11)),
                      const SizedBox(height: 16),
                    ],
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

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap != null
          ? () {
              AudioManager.instance.playClick();
              onTap!();
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Text(label,
                style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const Spacer(),
            trailing,
          ],
        ),
      ),
    );
  }
}
