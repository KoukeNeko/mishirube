import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

const _trackWidth = 10.0;
const _startAngle = -math.pi / 2;

/// How far this week has got, as a ring. Takes plain numbers: the same
/// ring is the page's hero and, small, the entry in the toolbar.
class WeeklyGoalRing extends StatelessWidget {
  const WeeklyGoalRing({
    super.key,
    required this.value,
    required this.target,
    this.size = 148,
    this.strokeWidth = _trackWidth,
    this.isPaused = false,
    this.child,
  });

  final int value;
  final int target;
  final double size;
  final double strokeWidth;
  final bool isPaused;

  /// What sits inside the ring; the page puts the numbers there.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final progress = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    return Semantics(
      label: isPaused ? '本週目標已暫停' : '本週 $value / $target 個運動日',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: isPaused ? 0 : progress,
            strokeWidth: strokeWidth,
            color: isPaused ? AppColors.textTertiary : AppColors.training,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
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
