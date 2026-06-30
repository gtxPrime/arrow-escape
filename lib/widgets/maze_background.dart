import 'dart:math';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class BlendedMazeBackground extends StatelessWidget {
  final double height;
  final double progress;

  const BlendedMazeBackground({
    super.key,
    this.height = 360,
    this.progress = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black,
            Colors.transparent,
          ],
          stops: [0.45, 1.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: CustomPaint(
          painter: MazeBackgroundPainter(
            baseColor: AppColors.textSecondary,
            progress: progress,
          ),
        ),
      ),
    );
  }
}

class MazeBackgroundPainter extends CustomPainter {
  final Color baseColor;
  final double progress;

  MazeBackgroundPainter({
    required this.baseColor,
    this.progress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(1337); // Seeded random for deterministic layout

    // Grid dots spacing
    final double spacing = 38.0;
    final int rows = (size.height / spacing).ceil();
    final int cols = (size.width / spacing).ceil();

    // Draw faint grid dots matching the game screen background
    final dotPaint = Paint()..color = baseColor.withValues(alpha: 0.12);
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        canvas.drawCircle(
          Offset(c * spacing + 19, r * spacing + 19),
          1.5,
          dotPaint,
        );
      }
    }

    // Number of arrow lines (12 is clean and avoids clutter)
    final int numArrows = 12;
    final colors = [
      AppColors.accentGold,
      AppColors.accentOrange,
      AppColors.accentGreen,
      AppColors.textSecondary,
    ];

    for (int i = 0; i < numArrows; i++) {
      final color = colors[rng.nextInt(colors.length)];
      final strokeWidth = 3.5 + rng.nextDouble() * 2.0;

      final arrowPaint = Paint()
        ..color = color.withValues(alpha: 0.18) // Crisp but subtle opacity
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // Distribute starting columns evenly across the width to avoid overlapping clusters
      final double colTarget = (i + 0.2 + rng.nextDouble() * 0.6) * (cols / numArrows);
      final int startCol = colTarget.floor().clamp(0, cols - 1);
      final int startRow = rng.nextInt((rows * 0.5).ceil().clamp(2, rows));

      var current = Offset(startCol * spacing + 19, startRow * spacing + 19);
      final List<Offset> pathPoints = [current];

      final length = 3 + rng.nextInt(3); // 3 to 5 segments
      var lastDir = rng.nextInt(4);
      var currentOffset = current;

      for (int j = 0; j < length; j++) {
        final List<int> validDirs = [];
        for (int d = 0; d < 4; d++) {
          // Avoid going directly backwards (reversing direction)
          if ((d - lastDir).abs() == 2) continue;

          final Offset delta;
          switch (d) {
            case 0: delta = Offset(spacing, 0); break;  // Right
            case 1: delta = Offset(0, spacing); break;  // Down
            case 2: delta = Offset(-spacing, 0); break; // Left
            default: delta = Offset(0, -spacing); break; // Up
          }

          final next = currentOffset + delta;
          // Keep paths bounded within canvas padding
          if (next.dx >= 15 && next.dx <= size.width - 15 &&
              next.dy >= 15 && next.dy <= size.height - 15) {
            validDirs.add(d);
          }
        }

        if (validDirs.isEmpty) break;

        // Prefer going down or sideways to simulate falling/clean structures
        if (validDirs.contains(1) && rng.nextDouble() < 0.6) {
          lastDir = 1;
        } else {
          lastDir = validDirs[rng.nextInt(validDirs.length)];
        }

        final Offset delta;
        switch (lastDir) {
          case 0: delta = Offset(spacing, 0); break;
          case 1: delta = Offset(0, spacing); break;
          case 2: delta = Offset(-spacing, 0); break;
          default: delta = Offset(0, -spacing); break;
        }

        currentOffset += delta;
        if (!pathPoints.contains(currentOffset)) {
          pathPoints.add(currentOffset);
        }
      }

      if (pathPoints.length < 2) continue;

      // Slice the path points based on animation progress
      final animatedPoints = _getAnimatedPoints(pathPoints, progress, spacing);
      if (animatedPoints.length < 2) continue;

      // Draw path body
      final path = Path()..moveTo(animatedPoints.first.dx, animatedPoints.first.dy);
      for (int k = 1; k < animatedPoints.length; k++) {
        path.lineTo(animatedPoints[k].dx, animatedPoints[k].dy);
      }
      canvas.drawPath(path, arrowPaint);

      // Draw arrowhead at the animated tip pointing exactly in forward direction
      final tip = animatedPoints.last;
      final prev = animatedPoints[animatedPoints.length - 2];
      final dv = tip - prev;
      final len = dv.distance;

      final dx = len > 0.01 ? dv.dx / len : 0.0;
      final dy = len > 0.01 ? dv.dy / len : -1.0;

      final double headSize = spacing * 0.32;
      final base = tip - Offset(dx * headSize, dy * headSize);
      final px = -dy, py = dx; // Perpendicular vector

      final caretPath = Path()
        ..moveTo(base.dx + px * headSize * 0.75, base.dy + py * headSize * 0.75)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(base.dx - px * headSize * 0.75, base.dy - py * headSize * 0.75);

      canvas.drawPath(
        caretPath,
        Paint()
          ..color = color.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  List<Offset> _getAnimatedPoints(List<Offset> points, double progress, double spacing) {
    if (points.isEmpty) return [];
    if (progress <= 0.0) return [];
    if (progress >= 1.0) return points;

    final double totalLength = (points.length - 1) * spacing;
    final double targetLength = totalLength * progress;

    final List<Offset> result = [points.first];
    double currentLength = 0.0;

    for (int i = 0; i < points.length - 1; i++) {
      final segmentStart = points[i];
      final segmentEnd = points[i + 1];

      if (currentLength + spacing <= targetLength) {
        result.add(segmentEnd);
        currentLength += spacing;
      } else {
        final double remaining = targetLength - currentLength;
        final double t = remaining / spacing;
        final Offset lerped = Offset.lerp(segmentStart, segmentEnd, t)!;
        result.add(lerped);
        break;
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant MazeBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.baseColor != baseColor;
  }
}
