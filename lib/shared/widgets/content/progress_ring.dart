import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

const _startAngle = -math.pi / 2;

/// How far something has got, as a ring filling clockwise from the top,
/// with whatever the page puts in its middle.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.color,
    required this.semanticLabel,
    this.size = 148,
    this.strokeWidth = 10,
    this.child,
  });

  /// From 0 to 1; anything past either end is drawn at it.
  final double progress;
  final Color color;
  final String semanticLabel;
  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    excludeSemantics: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0.0, 1.0),
          strokeWidth: strokeWidth,
          color: color,
        ),
        child: Center(child: child),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
  });

  final double progress;
  final double strokeWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = AppColors.surfaceRaised;
    canvas.drawCircle(centre, radius, track);
    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      _startAngle,
      progress * 2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
