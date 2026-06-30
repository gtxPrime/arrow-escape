import 'package:flutter/material.dart';
import '../data/models/arrow.dart';

class ArrowLine extends StatelessWidget {
  final ArrowDirection direction;
  final Color color;
  final double size;
  final double strokeWidth;

  const ArrowLine({
    super.key,
    required this.direction,
    required this.color,
    this.size = 52.0,
    this.strokeWidth = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: ArrowLinePainter(
          direction: direction,
          color: color,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class ArrowLinePainter extends CustomPainter {
  final ArrowDirection direction;
  final Color color;
  final double strokeWidth;

  ArrowLinePainter({
    required this.direction,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final double w = size.width;
    final double h = size.height;

    final Offset start;
    final Offset end;
    final Offset arrowhead1;
    final Offset arrowhead2;

    final double padding = strokeWidth * 1.5;
    final double headSize = size.width * 0.32;

    switch (direction) {
      case ArrowDirection.left:
        start = Offset(w - padding, h / 2);
        end = Offset(padding, h / 2);
        arrowhead1 = Offset(end.dx + headSize, end.dy - headSize * 0.7);
        arrowhead2 = Offset(end.dx + headSize, end.dy + headSize * 0.7);
        break;
      case ArrowDirection.right:
        start = Offset(padding, h / 2);
        end = Offset(w - padding, h / 2);
        arrowhead1 = Offset(end.dx - headSize, end.dy - headSize * 0.7);
        arrowhead2 = Offset(end.dx - headSize, end.dy + headSize * 0.7);
        break;
      case ArrowDirection.up:
        start = Offset(w / 2, h - padding);
        end = Offset(w / 2, padding);
        arrowhead1 = Offset(end.dx - headSize * 0.7, end.dy + headSize);
        arrowhead2 = Offset(end.dx + headSize * 0.7, end.dy + headSize);
        break;
      case ArrowDirection.down:
        start = Offset(w / 2, padding);
        end = Offset(w / 2, h - padding);
        arrowhead1 = Offset(end.dx - headSize * 0.7, end.dy - headSize);
        arrowhead2 = Offset(end.dx + headSize * 0.7, end.dy - headSize);
        break;
    }

    // Draw main arrow body line
    canvas.drawLine(start, end, paint);

    // Draw caret arrowhead pointing in direction
    final path = Path()
      ..moveTo(arrowhead1.dx, arrowhead1.dy)
      ..lineTo(end.dx, end.dy)
      ..lineTo(arrowhead2.dx, arrowhead2.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ArrowLinePainter oldDelegate) {
    return oldDelegate.direction != direction ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
