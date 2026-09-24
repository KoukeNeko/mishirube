import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Minimal bar chart; the last bar is highlighted as "current period",
/// or the [selected] one while a reading picks it.
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    super.key,
    required this.bars,
    this.height = 80,
    this.showLabels = true,
    this.color = AppColors.training,
    this.dimColor = AppColors.trainingDim,
    this.selected,
  });

  final List<(String, int)> bars;
  final double height;
  final bool showLabels;
  final int? selected;

  /// The last bar's colour, and the others'.
  final Color color;
  final Color dimColor;

  @override
  Widget build(BuildContext context) {
    final highest = bars.map((bar) => bar.$2).fold(0, (a, b) => a > b ? a : b);
    // All zero is a row of empty bars, not a division by zero.
    final maxValue = highest == 0 ? 1 : highest;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < bars.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: height * bars[i].$2 / maxValue,
                  decoration: BoxDecoration(
                    color: i == (selected ?? bars.length - 1)
                        ? color
                        : dimColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ),
                if (showLabels) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(bars[i].$1, style: AppTextStyles.caption),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Line chart without axes, ending in a dot on the latest value, or
/// marking the [selected] one while a reading picks it.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.color = AppColors.body,
    this.height = 48,
    this.selected,
  });

  final List<double> values;
  final Color color;
  final double height;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          color: color,
          selected: selected,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.selected,
  });

  static const _endDotRadius = 4.0;

  final List<double> values;
  final Color color;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs() < 0.001 ? 1 : maxValue - minValue;
    final stepX = (size.width - _endDotRadius) / (values.length - 1);

    Offset pointAt(int index) => Offset(
      index * stepX,
      _endDotRadius +
          (maxValue - values[index]) /
              range *
              (size.height - _endDotRadius * 2),
    );

    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(pointAt(i).dx, pointAt(i).dy);
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawCircle(
        pointAt(selected ?? values.length - 1),
        _endDotRadius,
        Paint()..color = color,
      );
    if (selected case final index?) {
      final x = pointAt(index).dx;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.color != color ||
      oldDelegate.selected != selected;
}
