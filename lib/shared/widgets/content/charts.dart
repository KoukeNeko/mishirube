import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Minimal bar chart; the last bar is highlighted as "current period"
/// unless [highlightsLast] is off, or the [selected] one while a reading
/// picks it. Many bars sit closer together, so a month or a day of hours
/// still has bars rather than gaps.
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    super.key,
    required this.bars,
    this.height = 80,
    this.showLabels = true,
    this.color = AppColors.training,
    this.dimColor = AppColors.trainingDim,
    this.selected,
    this.highlightsLast = true,
  });

  final List<(String, int)> bars;
  final double height;
  final bool showLabels;
  final int? selected;
  final bool highlightsLast;

  /// The last bar's colour, and the others'.
  final Color color;
  final Color dimColor;

  @override
  Widget build(BuildContext context) {
    final highest = bars.map((bar) => bar.$2).fold(0, (a, b) => a > b ? a : b);
    // All zero is a row of empty bars, not a division by zero.
    final maxValue = highest == 0 ? 1 : highest;
    final highlighted = selected ?? (highlightsLast ? bars.length - 1 : null);
    final gap = bars.length > 14 ? 2.0 : AppSpacing.xs;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < bars.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: height * bars[i].$2 / maxValue,
                  decoration: BoxDecoration(
                    color: highlighted == null || i == highlighted
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

/// A stretch of a [Sparkline] drawn as one flat level: an average over
/// those points, rather than a fitted line.
class ChartLevel {
  const ChartLevel({
    required this.value,
    required this.from,
    required this.to,
    required this.color,
  });

  final double value;

  /// The first and last point it spans.
  final int from;
  final int to;
  final Color color;
}

/// Line chart without axes, ending in a dot on the latest value, or
/// marking the [selected] one while a reading picks it. A null value is
/// a gap the line breaks at rather than bridges. Behind the line it can
/// show a [normal] band and [levels] across the stretches they average.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.color = AppColors.body,
    this.height = 48,
    this.selected,
    this.normal,
    this.levels = const [],
  });

  final List<double?> values;
  final Color color;
  final double height;
  final int? selected;

  /// The low and high edge of what is normal.
  final (double, double)? normal;
  final List<ChartLevel> levels;

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
          normal: normal,
          levels: levels,
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
    required this.normal,
    required this.levels,
  });

  static const _endDotRadius = 4.0;
  static const _loneDotRadius = 2.0;
  static const _bandAlpha = 0.14;

  final List<double?> values;
  final Color color;
  final int? selected;
  final (double, double)? normal;
  final List<ChartLevel> levels;

  @override
  void paint(Canvas canvas, Size size) {
    final known = [...values.nonNulls];
    if (known.length < 2 && levels.isEmpty) return;
    final all = [
      ...known,
      if (normal case (final low, final high)) ...[low, high],
      for (final level in levels) level.value,
    ];
    final minValue = all.reduce((a, b) => a < b ? a : b);
    final maxValue = all.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs() < 0.001 ? 1 : maxValue - minValue;
    final stepX = values.length < 2
        ? 0.0
        : (size.width - _endDotRadius) / (values.length - 1);
    double xOf(int index) => index * stepX;
    double yOf(double value) =>
        _endDotRadius +
        (maxValue - value) / range * (size.height - _endDotRadius * 2);

    if (normal case (final low, final high)) {
      canvas.drawRect(
        Rect.fromLTRB(0, yOf(high), size.width, yOf(low)),
        Paint()..color = AppColors.textSecondary.withValues(alpha: _bandAlpha),
      );
    }
    for (final level in levels) {
      canvas.drawLine(
        Offset(xOf(level.from), yOf(level.value)),
        Offset(xOf(level.to), yOf(level.value)),
        Paint()
          ..color = level.color
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    Path? path;
    var run = 0;
    void endRun(int last) {
      if (run == 1) {
        // A point alone between gaps would otherwise not show at all.
        canvas.drawCircle(
          Offset(xOf(last), yOf(values[last]!)),
          _loneDotRadius,
          Paint()..color = color,
        );
      } else if (path != null) {
        canvas.drawPath(path!, line);
      }
      path = null;
      run = 0;
    }

    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) {
        endRun(i - 1);
        continue;
      }
      final point = Offset(xOf(i), yOf(value));
      path == null
          ? path = (Path()..moveTo(point.dx, point.dy))
          : path!.lineTo(point.dx, point.dy);
      run++;
    }
    endRun(values.length - 1);

    final last = values.lastIndexWhere((value) => value != null);
    final marked = selected != null && values[selected!] != null
        ? selected!
        : last;
    if (marked >= 0) {
      canvas.drawCircle(
        Offset(xOf(marked), yOf(values[marked]!)),
        _endDotRadius,
        Paint()..color = color,
      );
    }
    if (selected case final index?) {
      canvas.drawLine(
        Offset(xOf(index), 0),
        Offset(xOf(index), size.height),
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
      oldDelegate.selected != selected ||
      oldDelegate.normal != normal ||
      oldDelegate.levels != levels;
}
