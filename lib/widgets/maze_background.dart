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

    // Keep track of occupied cells to prevent paths from ever overlapping
    final Set<String> occupiedCells = {};
    String cellKey(int r, int c) => '$r,$c';

    // A clean density of 15 non-overlapping paths
    final int numArrows = 15;
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
        ..color = color // Fully solid color to hide grid dots beneath it
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // Find an unoccupied starting cell for this path
      int startRow = 0;
      int startCol = 0;
      bool foundStart = false;

      for (int attempt = 0; attempt < 30; attempt++) {
        final double colTarget = (i + 0.1 + rng.nextDouble() * 0.8) * (cols / numArrows);
        final int c = colTarget.floor().clamp(0, cols - 1);
        final int r = rng.nextInt((rows * 0.6).ceil().clamp(2, rows));

        if (!occupiedCells.contains(cellKey(r, c))) {
          startRow = r;
          startCol = c;
          foundStart = true;
          break;
        }
      }

      if (!foundStart) continue;

      final List<Offset> pathPoints = [
        Offset(startCol * spacing + 19, startRow * spacing + 19)
      ];
      occupiedCells.add(cellKey(startRow, startCol));

      final int pathLength = 3 + rng.nextInt(3); // 3 to 5 segments
      int currentValR = startRow;
      int currentValC = startCol;
      int lastDir = rng.nextInt(4);

      for (int j = 0; j < pathLength; j++) {
        final List<int> validDirs = [];
        for (int d = 0; d < 4; d++) {
          // Avoid reversing direction immediately
          if ((d - lastDir).abs() == 2) continue;

          int nextR = currentValR;
          int nextC = currentValC;
          switch (d) {
            case 0: nextC++; break; // Right
            case 1: nextR++; break; // Down
            case 2: nextC--; break; // Left
            default: nextR--; break; // Up
          }

          if (nextC >= 0 && nextC < cols && nextR >= 0 && nextR < rows) {
            if (!occupiedCells.contains(cellKey(nextR, nextC))) {
              validDirs.add(d);
            }
          }
        }

        if (validDirs.isEmpty) break;

        // Choose next direction, biasing slightly towards down
        if (validDirs.contains(1) && rng.nextDouble() < 0.5) {
          lastDir = 1;
        } else {
          lastDir = validDirs[rng.nextInt(validDirs.length)];
        }

        switch (lastDir) {
          case 0: currentValC++; break;
          case 1: currentValR++; break;
          case 2: currentValC--; break;
          default: currentValR--; break;
        }

        pathPoints.add(Offset(currentValC * spacing + 19, currentValR * spacing + 19));
        occupiedCells.add(cellKey(currentValR, currentValC));
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

      // Draw arrowhead at the leading tip pointing exactly in the direction of traversal
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
          ..color = color
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
