import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class LivesBar extends StatefulWidget {
  final int lives;
  final int maxLives;

  const LivesBar({super.key, required this.lives, required this.maxLives});

  @override
  State<LivesBar> createState() => _LivesBarState();
}

class _LivesBarState extends State<LivesBar> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.maxLives, (i) {
        final isFull = i < widget.lives;

        final heartWidget = Stack(
          alignment: Alignment.center,
          children: [
            // Soft drop shadow for 3D depth
            if (isFull)
              Icon(
                Icons.favorite,
                color: Colors.black.withValues(alpha: 0.15),
                size: 27,
              ),
            // Heart body
            isFull
                ? ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF829079), Color(0xFF5E6B56)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 25,
                    ),
                  )
                : Icon(
                    Icons.favorite_border,
                    color: AppColors.surfaceLight,
                    size: 24,
                  ),
            // Glass/glossy reflection dot on top-left of active heart
            if (isFull)
              Positioned(
                top: 5,
                left: 5,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: isFull
                ? ScaleTransition(
                    key: ValueKey('heart_${i}_full'),
                    scale: _scaleAnimation,
                    child: heartWidget,
                  )
                : SizedBox(
                    key: ValueKey('heart_${i}_empty'),
                    child: heartWidget,
                  ),
          ),
        );
      }),
    );
  }
}
