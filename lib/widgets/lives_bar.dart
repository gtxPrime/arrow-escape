import 'package:flutter/material.dart';

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
          padding: const EdgeInsets.symmetric(horizontal: 2.5),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              Icons.favorite,
              key: ValueKey('heart_${i}_$isFull'),
              color: isFull ? const Color(0xFFFF2D55) : const Color(0xFFDDD5C3),
              size: 24,
            ),
          ),
        );
      }),
    );
  }
}
