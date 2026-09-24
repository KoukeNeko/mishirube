import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Each weighing as a faint dot and the trend through them as the line:
/// the line is the one to read, since a single day's figure moves with
/// water and food.
class WeightTrendChart extends StatelessWidget {
  const WeightTrendChart({super.key, required this.points, this.selected});

  /// Weighings with their trend, oldest first.
  final List<(DateTime, double weight, double trend)> points;

  /// The weighing being read, marked on the line.
  final int? selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      width: double.infinity,
      child: CustomPaint(
        painter: _TrendPainter(points: points, selected: selected),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.points, required this.selected});

  static const _inset = 6.0;

  final List<(DateTime, double, double)> points;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final values = [
      for (final (_, w, t) in points) ...[w, t],
    ];
    final low = values.reduce((a, b) => a < b ? a : b);
    final high = values.reduce((a, b) => a > b ? a : b);
    final range = (high - low).abs() < 0.1 ? 1.0 : high - low;
    double x(int index) => points.length < 2
        ? size.width / 2
        : _inset + index * (size.width - _inset * 2) / (points.length - 1);
    double y(double value) =>
        _inset + (high - value) / range * (size.height - _inset * 2);

    final raw = Paint()..color = AppColors.body.withValues(alpha: 0.35);
    for (final (index, (_, weight, _)) in points.indexed) {
      canvas.drawCircle(Offset(x(index), y(weight)), 2.5, raw);
    }
    final line = Path();
    for (final (index, (_, _, trend)) in points.indexed) {
      final point = Offset(x(index), y(trend));
      index == 0
          ? line.moveTo(point.dx, point.dy)
          : line.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.body
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final marked = selected ?? points.length - 1;
    final (_, weight, trend) = points[marked];
    if (selected != null) {
      canvas.drawLine(
        Offset(x(marked), 0),
        Offset(x(marked), size.height),
        Paint()
          ..color = AppColors.body.withValues(alpha: 0.4)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        Offset(x(marked), y(weight)),
        3.5,
        Paint()..color = AppColors.textPrimary,
      );
    }
    canvas.drawCircle(
      Offset(x(marked), y(trend)),
      4.5,
      Paint()..color = AppColors.body,
    );
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points != points || old.selected != selected;
}
