import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class LivesBar extends StatelessWidget {
  final int lives;
  final int maxLives;

  const LivesBar({super.key, required this.lives, required this.maxLives});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxLives, (i) {
        final isFull = i < lives;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: Opacity(
              key: ValueKey('droplet_${i}_$isFull'),
              opacity: isFull ? 1.0 : 0.22,
              child: const Icon(
                LucideIcons.droplet,
                color: Color(0xFF3498DB),
                size: 24,
              ),
            ),
          ),
        );
      }),
    );
  }
}
