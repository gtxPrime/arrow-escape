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

    // Draw tangled paths of arrow lines in theme colors (increased density to 24)
    final int numArrows = 24;
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
        ..color = color.withValues(alpha: 0.14) // Softer alpha for higher density grid
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // Select random starting grid point
      final startCol = rng.nextInt(cols);
      final startRow = rng.nextInt(rows);
      var current = Offset(startCol * spacing + 19, startRow * spacing + 19);

      final path = Path()..moveTo(current.dx, current.dy);
      final length = 4 + rng.nextInt(4); // 4 to 7 segments

      var lastDir = rng.nextInt(4);
      var currentOffset = current;

      for (int j = 0; j < length; j++) {
        // Decide direction: keep going or turn
        if (rng.nextDouble() < 0.45) {
          lastDir = (lastDir + (rng.nextBool() ? 1 : 3)) % 4;
        }

        final Offset delta;
        switch (lastDir) {
          case 0: delta = Offset(spacing, 0); break;  // Right
          case 1: delta = Offset(0, spacing); break;  // Down
          case 2: delta = Offset(-spacing, 0); break; // Left
          default: delta = Offset(0, -spacing); break; // Up
        }

        final nextOffset = currentOffset + delta;
        // Keep within horizontal bounds
        if (nextOffset.dx >= 0 && nextOffset.dx <= size.width) {
          currentOffset = nextOffset;
          path.lineTo(currentOffset.dx, currentOffset.dy);
        }
      }

      // Render animated path and animated arrowhead
      for (final pathMetric in path.computeMetrics()) {
        final double currentLength = pathMetric.length * progress;
        if (currentLength > 0.0) {
          final extract = pathMetric.extractPath(0.0, currentLength);
          canvas.drawPath(extract, arrowPaint);

          // Draw the caret arrowhead at the animated tip position
          final tangent = pathMetric.getTangentForOffset(currentLength);
          if (tangent != null) {
            final double headSize = spacing * 0.32;
            final tip = tangent.position;
            final angle = tangent.angle;

            final dx = cos(angle);
            final dy = sin(angle);
            final endDir = Offset(dx, dy);

            final base = tip - endDir * headSize;
            final px = -endDir.dy, py = endDir.dx; // Perpendicular vector

            final caretPath = Path()
              ..moveTo(base.dx + px * headSize * 0.75, base.dy + py * headSize * 0.75)
              ..lineTo(tip.dx, tip.dy)
              ..lineTo(base.dx - px * headSize * 0.75, base.dy - py * headSize * 0.75);

            canvas.drawPath(
              caretPath,
              Paint()
                ..color = color.withValues(alpha: 0.14)
                ..style = PaintingStyle.stroke
                ..strokeWidth = strokeWidth
                ..strokeCap = StrokeCap.round
                ..strokeJoin = StrokeJoin.round,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant MazeBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.baseColor != baseColor;
  }
}
