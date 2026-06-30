import 'package:flutter/material.dart';
import 'dart:math';
import '../core/app_colors.dart';

/// A custom progress bar with a horizontal liquid filling animation.
/// The height is completely filled, the progress transition is smoothed out,
/// and it ripples dynamically along the leading edge (filling front).
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

class _WavyProgressBarState extends State<WavyProgressBar>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    // Controls the wave ripple animation speed
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    // Controls the smooth transitions when progress changes
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    ));

    _progressController.forward();
  }

  @override
  void didUpdateWidget(WavyProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: widget.progress,
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeOutCubic,
      ));
      _progressController.reset();
      _progressController.forward();
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_waveController, _progressAnimation]),
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _WavyProgressBarPainter(
            progress: _progressAnimation.value,
            animationValue: _waveController.value,
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

    // Draw background track (light surface color)
    final bgPaint = Paint()
      ..color = AppColors.surfaceLight
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    if (progress <= 0.0) return;

    canvas.save();
    // Clip to the progress bar rounded rectangle shape
    canvas.clipRRect(rrect);

    // Draw wavy liquid fill using solid pinkish-red color
    final fillPaint = Paint()
      ..color = const Color(0xFFFF2D55)
      ..style = PaintingStyle.fill;

    final fillWidth = progress * width;
    final wavePath = Path();

    // Wave properties for the vertical front edge
    final waveAmplitude = height * 0.28; // height-relative wave amplitude
    const waveFrequency = 1.0;          // 1 full cycle along the height

    wavePath.moveTo(0, 0);
    wavePath.lineTo(fillWidth, 0);

    // Draw a wavy vertical front edge from top (y = 0) to bottom (y = height)
    for (double y = 0; y <= height; y++) {
      final x = fillWidth +
          sin((y / height * waveFrequency * 2 * pi) -
                  (animationValue * 2 * pi)) *
              waveAmplitude;
      wavePath.lineTo(max(0.0, x), y);
    }

    wavePath.lineTo(0, height);
    wavePath.close();

    canvas.drawPath(wavePath, fillPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WavyProgressBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.animationValue != animationValue;
  }
}
