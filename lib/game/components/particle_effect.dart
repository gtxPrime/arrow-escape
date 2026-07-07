import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import '../../../data/models/arrow.dart';

/// Particle burst effect when an arrow exits the grid.
class ExitParticleEffect extends ParticleSystemComponent {
  ExitParticleEffect({
    required Vector2 position,
    required ArrowDirection direction,
  }) : super(
          position: position,
          particle: Particle.generate(
            count: 12,
            lifespan: 0.5,
            generator: (i) {
              final rng = Random();
              final angle = (i / 12) * 2 * pi + rng.nextDouble() * 0.4;
              final speed = 40 + rng.nextDouble() * 80;
              final color = _particleColors[i % _particleColors.length];
              return AcceleratedParticle(
                position: Vector2.zero(),
                speed: Vector2(cos(angle) * speed, sin(angle) * speed),
                acceleration: Vector2(0, 120), // Gravity
                child: CircleParticle(
                  radius: 3 + rng.nextDouble() * 4,
                  paint: Paint()..color = color.withValues(alpha: 0.9),
                ),
              );
            },
          ),
        );

  static final _particleColors = [
    AppColors.primary,
    AppColors.accentGold,
    AppColors.accentGreen,
    AppColors.primaryLight,
    AppColors.accent,
  ];
}
