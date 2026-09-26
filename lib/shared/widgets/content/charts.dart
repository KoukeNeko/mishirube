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

/// A span of time in equal stretches, each drawn as a bar from its lowest
/// to its highest value, with the lowest and highest of all marked and
/// labelled: how a night's heart rate or breathing moved. A stretch
/// without a value is left empty. [labelOf] writes a value for the
/// marks; [start] and [end] sit under the ends of the axis.
class RangeBarChart extends StatelessWidget {
  const RangeBarChart({
    super.key,
    required this.ranges,
    required this.color,
    required this.labelOf,
    required this.start,
    required this.end,
    this.height = 180,
    this.selected,
  });

  final List<(double, double)?> ranges;
  final Color color;
  final String Function(double value) labelOf;
  final String start;
  final String end;
  final double height;

  /// The stretch a reading picks; the others dim while one is picked.
  final int? selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _RangeBarPainter(
              ranges: ranges,
              color: color,
              selected: selected,
              labelOf: labelOf,
              labelStyle: AppTextStyles.caption.copyWith(color: color),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Text(start, style: AppTextStyles.caption),
            const Spacer(),
            Text(end, style: AppTextStyles.caption),
          ],
        ),
      ],
    );
  }
}

class _RangeBarPainter extends CustomPainter {
  _RangeBarPainter({
    required this.ranges,
    required this.color,
    required this.labelOf,
    required this.labelStyle,
    required this.selected,
  });

  /// Room kept above and below the bars for the labels of the extremes.
  static const _labelRoom = 22.0;
  static const _barShare = 0.45;
  static const _markRadius = 3.0;

  final List<(double, double)?> ranges;
  final Color color;
  final String Function(double value) labelOf;
  final TextStyle labelStyle;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final known = [
      for (final (index, range) in ranges.indexed)
        if (range != null) (index, range),
    ];
    if (known.isEmpty) return;
    var low = known.first.$2.$1;
    var high = known.first.$2.$2;
    var lowAt = known.first.$1;
    var highAt = known.first.$1;
    for (final (index, (bottom, top)) in known) {
      if (bottom < low) (low, lowAt) = (bottom, index);
      if (top > high) (high, highAt) = (top, index);
    }
    final span = (high - low).abs() < 0.001 ? 1.0 : high - low;
    final slot = size.width / ranges.length;
    final barWidth = slot * _barShare;
    final top = _labelRoom;
    final bottom = size.height - _labelRoom;
    double xOf(int index) => slot * (index + 0.5);
    double yOf(double value) => top + (high - value) / span * (bottom - top);

    final paint = Paint()
      ..color = color
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;
    final dimmed = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;
    for (final (index, (bottomValue, topValue)) in known) {
      canvas.drawLine(
        Offset(xOf(index), yOf(topValue)),
        Offset(xOf(index), yOf(bottomValue)),
        selected == null || selected == index ? paint : dimmed,
      );
    }

    void mark(int index, double value, {required bool above}) {
      final point = Offset(xOf(index), yOf(value));
      canvas.drawCircle(point, _markRadius, Paint()..color = AppColors.surface);
      final text = TextPainter(
        text: TextSpan(text: labelOf(value), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (point.dx - text.width / 2).clamp(0.0, size.width - text.width);
      text.paint(
        canvas,
        Offset(
          x,
          above
              ? point.dy - barWidth / 2 - text.height - 2
              : point.dy + barWidth / 2 + 2,
        ),
      );
    }

    mark(highAt, high, above: true);
    mark(lowAt, low, above: false);
  }

  @override
  bool shouldRepaint(_RangeBarPainter old) =>
      old.ranges != ranges || old.color != color || old.selected != selected;
}
