import 'package:flutter/material.dart';
import 'dart:math';
import '../core/app_colors.dart';

/// A custom progress bar with a horizontal wavy liquid filling animation.
class WavyProgressBar extends StatefulWidget {
  final double progress;
  final double width;
  final double height;

  const WavyProgressBar({
    super.key,
    required this.progress,
    this.width = 100,
    this.height = 8,
  });

  @override
  State<WavyProgressBar> createState() => _WavyProgressBarState();
}

class _WavyProgressBarState extends State<WavyProgressBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _WavyProgressBarPainter(
            progress: widget.progress,
            animationValue: _controller.value,
          ),
        );
      },
    );
  }
}

class _WavyProgressBarPainter extends CustomPainter {
  final double progress;
  final double animationValue;

  _WavyProgressBarPainter({
    required this.progress,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      Radius.circular(height / 2),
    );

    // Draw background track
    final bgPaint = Paint()
      ..color = AppColors.surfaceLight
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    if (progress <= 0.0) return;

    canvas.save();
    // Clip to progress bar shape
    canvas.clipRRect(rrect);

    // Draw wavy liquid fill using the game's accent color (pinkish-red gradient)
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFF527B), // Vibrant light pinkish-red
          Color(0xFFE91E63), // Deep rose pinkish-red
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    final fillWidth = progress * width;
    final wavePath = Path();
    
    // Wave ripple amplitude and wavelength
    final waveHeight = height * 0.35; 
    final waveLength = width * 0.45;  

    wavePath.moveTo(0, height);
    // Left edge start height: starts at middle and goes wavy
    wavePath.lineTo(0, height * 0.4);

    for (double x = 0; x <= fillWidth; x++) {
      // Sine wave offset by animationValue to create a flowing liquid movement
      final y = (height * 0.4) + sin((x / waveLength * 2 * pi) - (animationValue * 2 * pi)) * waveHeight;
      wavePath.lineTo(x, y);
    }
    
    // Connect back to create a solid fill shape
    if (progress >= 1.0) {
      wavePath.lineTo(width, 0);
    } else {
      wavePath.lineTo(fillWidth, height);
    }
    
    wavePath.lineTo(0, height);
    wavePath.close();

    canvas.drawPath(wavePath, fillPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WavyProgressBarPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.animationValue != animationValue;
  }
}
