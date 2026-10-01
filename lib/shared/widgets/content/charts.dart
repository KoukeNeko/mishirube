import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'chart_entrance.dart';

const _dash = 5.0;
const _dashGap = 4.0;

/// [path] broken into dashes: the one way a chart draws a value that was
/// worked out by a model rather than measured or counted.
Path _dashed(Path path) {
  final dashes = Path();
  for (final metric in path.computeMetrics()) {
    for (var at = 0.0; at < metric.length; at += _dash + _dashGap) {
      dashes.addPath(metric.extractPath(at, at + _dash), Offset.zero);
    }
  }
  return dashes;
}

/// Minimal chart of capsule bars; the last bar is highlighted as "current
/// period", its label on a capsule, unless [highlightsLast] is off, or the
/// [selected] one while a reading picks it. Many bars sit closer
/// together, so a month or a day of hours still has bars rather than
/// gaps. A null value is nothing recorded and leaves its slot empty; a
/// true zero is a thin line on the axis. A [goal] is a thin line across,
/// and each bar in [met] carries a check at its top: which bars met the
/// goal is the caller's to say, since a goal may be a floor, a ceiling or
/// a range, and a day still going may not count.
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
    this.goal,
    this.met = const {},
    this.top,
  });

  final List<(String, int?)> bars;

  /// How tall a zero is drawn, so it reads apart from nothing recorded.
  static const _zeroHeight = 2.0;

  final double height;
  final bool showLabels;
  final int? selected;
  final bool highlightsLast;

  /// In the bars' own units.
  final int? goal;

  /// Indexes of the bars that met the [goal].
  final Set<int> met;

  /// What the full height stands for when the scale has a natural top,
  /// such as the seven nights of a week; otherwise the highest bar or
  /// goal.
  final int? top;

  /// The last bar's colour, and the others'.
  final Color color;
  final Color dimColor;

  @override
  Widget build(BuildContext context) {
    final highest = [
      for (final bar in bars) bar.$2 ?? 0,
      ?goal,
      ?top,
    ].fold(0, (a, b) => a > b ? a : b);
    // All zero is a row of empty bars, not a division by zero.
    final maxValue = highest == 0 ? 1 : highest;
    // The period still going, marked under its bar as Health apps mark
    // today; it stays marked while a reading picks another bar.
    final current = highlightsLast ? bars.length - 1 : null;
    final highlighted = selected ?? current;
    final gap = bars.length > 14 ? 2.0 : AppSpacing.xs;
    List<Widget> slots(Widget Function(int index) slot) => [
      for (var i = 0; i < bars.length; i++) ...[
        if (i > 0) SizedBox(width: gap),
        Expanded(child: slot(i)),
      ],
    ];
    final check = Color.lerp(color, AppColors.textPrimary, 0.6)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: Stack(
            children: [
              if (goal case final goal?)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: height * goal / maxValue,
                  child: Container(height: 1, color: color),
                ),
              Positioned.fill(
                // The bars rise one after another; a check shows as its
                // bar reaches the top.
                child: ChartEntrance(
                  shows: [for (final bar in bars) bar.$2],
                  builder: (context, progress) => Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: slots((i) {
                      final grown = staggeredProgress(progress, i, bars.length);
                      return switch (bars[i].$2) {
                        final value? => Container(
                          height: value == 0
                              ? _zeroHeight
                              : height * value / maxValue * grown,
                          padding: const EdgeInsets.all(2),
                          alignment: Alignment.topCenter,
                          decoration: ShapeDecoration(
                            color: highlighted == null || i == highlighted
                                ? color
                                : dimColor,
                            shape: const StadiumBorder(),
                          ),
                          // Nearly as wide as the bar, at its top.
                          child: met.contains(i)
                              ? Opacity(
                                  opacity: grown,
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: FittedBox(
                                      child: Icon(Icons.verified, color: check),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        null => const SizedBox.shrink(),
                      };
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showLabels) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: slots(
              // Every label padded alike; only the current period's is
              // filled.
              (i) => Center(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: i == current
                        ? AppColors.surfaceRaised
                        : Colors.transparent,
                    shape: const StadiumBorder(),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 2,
                    ),
                    child: Text(
                      bars[i].$1,
                      maxLines: 1,
                      softWrap: false,
                      style: i == current
                          ? AppTextStyles.caption.copyWith(
                              color: AppColors.textPrimary,
                            )
                          : AppTextStyles.caption,
                    ),
                  ),
                ),
              ),
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
/// show a [normal] band, or a usual range of its own for each point
/// ([bands], which moves as the days do), and [levels] across the
/// stretches they average. Points in [outside] are ringed, not coloured:
/// apart from the usual range is not worse. A line of estimates
/// ([isEstimate], such as an estimated max) is dashed.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.color = AppColors.body,
    this.height = 48,
    this.selected,
    this.normal,
    this.bands,
    this.outside = const {},
    this.levels = const [],
    this.isEstimate = false,
  });

  final List<double?> values;
  final Color color;
  final double height;
  final int? selected;
  final bool isEstimate;

  /// The low and high edge of what is normal.
  final (double, double)? normal;

  /// Each point's own usual range, aligned with [values]; null where
  /// there is none yet.
  final List<(double, double)?>? bands;

  /// Indexes of points outside their usual range.
  final Set<int> outside;
  final List<ChartLevel> levels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      // The line draws itself in from the left.
      child: ChartEntrance(
        shows: values,
        builder: (context, progress) => CustomPaint(
          painter: _SparklinePainter(
            values: values,
            color: color,
            selected: selected,
            normal: normal,
            bands: bands,
            outside: outside,
            levels: levels,
            isEstimate: isEstimate,
            progress: easedProgress(progress),
          ),
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
    required this.bands,
    required this.outside,
    required this.levels,
    required this.isEstimate,
    required this.progress,
  });

  static const _endDotRadius = 4.0;
  static const _ringRadius = 3.5;
  static const _loneDotRadius = 2.0;
  static const _bandAlpha = 0.14;

  final List<double?> values;
  final Color color;
  final int? selected;
  final (double, double)? normal;
  final List<(double, double)?>? bands;
  final Set<int> outside;
  final List<ChartLevel> levels;
  final bool isEstimate;

  /// How much of the line is drawn in, left to right.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final known = [...values.nonNulls];
    // One week is still a point to show; only nothing at all is blank.
    if (known.isEmpty && levels.isEmpty) return;
    final all = [
      ...known,
      if (normal case (final low, final high)) ...[low, high],
      for (final band in bands ?? const <(double, double)?>[])
        if (band case (final low, final high)) ...[low, high],
      for (final level in levels) level.value,
    ];
    final minValue = all.reduce((a, b) => a < b ? a : b);
    final maxValue = all.reduce((a, b) => a > b ? a : b);
    // A single value, or a line that never moves, sits in the middle
    // rather than along the top edge.
    final isFlat = (maxValue - minValue).abs() < 0.001;
    final range = isFlat ? 1 : maxValue - minValue;
    final stepX = values.length < 2
        ? 0.0
        : (size.width - _endDotRadius) / (values.length - 1);
    double xOf(int index) => index * stepX;
    double yOf(double value) => isFlat
        ? size.height / 2
        : _endDotRadius +
              (maxValue - value) / range * (size.height - _endDotRadius * 2);

    if (normal case (final low, final high)) {
      canvas.drawRect(
        Rect.fromLTRB(0, yOf(high), size.width, yOf(low)),
        Paint()..color = AppColors.textSecondary.withValues(alpha: _bandAlpha),
      );
    }
    // Each point's range covers its own stretch of the line, from halfway
    // to the point before to halfway to the next.
    if (bands case final bands?) {
      final band = Paint()
        ..color = AppColors.textSecondary.withValues(alpha: _bandAlpha);
      for (final (index, range) in bands.indexed) {
        if (range case (final low, final high)) {
          final half = stepX / 2;
          canvas.drawRect(
            Rect.fromLTRB(
              index == 0 ? 0 : xOf(index) - half,
              yOf(high),
              index == bands.length - 1 ? size.width : xOf(index) + half,
              yOf(low),
            ),
            band,
          );
        }
      }
    }
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        -_endDotRadius,
        -_endDotRadius,
        size.width * progress + _endDotRadius,
        size.height + _endDotRadius,
      ),
    );
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
        canvas.drawPath(isEstimate ? _dashed(path!) : path!, line);
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

    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final index in outside) {
      if (index >= values.length || values[index] == null) continue;
      final point = Offset(xOf(index), yOf(values[index]!));
      canvas.drawCircle(point, _ringRadius, Paint()..color = AppColors.surface);
      canvas.drawCircle(point, _ringRadius, ring);
    }

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
    canvas.restore();
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
      oldDelegate.bands != bands ||
      oldDelegate.outside != outside ||
      oldDelegate.levels != levels ||
      oldDelegate.isEstimate != isEstimate ||
      oldDelegate.progress != progress;
}

/// A span of time in equal stretches, each drawn as a bar from its lowest
/// to its highest value, with the lowest and highest of all marked and
/// labelled: how a night's heart rate or breathing moved. A stretch
/// without a value is left empty. [labelOf] writes a value for the
/// marks; [start] and [end] sit under the ends of the axis. Values grow
/// upward, or [downward] for times of day, which read down the way a
/// night goes from bedtime to waking. [levels] are targets, each a thin
/// solid line across; the axis stretches to hold them.
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
    this.downward = false,
    this.levels = const [],
  });

  final List<(double, double)?> ranges;
  final Color color;
  final String Function(double value) labelOf;
  final String start;
  final String end;
  final double height;

  /// The stretch a reading picks; the others dim while one is picked.
  final int? selected;
  final bool downward;
  final List<double> levels;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          // Each bar opens out from its middle, one after another.
          child: ChartEntrance(
            shows: ranges,
            builder: (context, progress) => CustomPaint(
              painter: _RangeBarPainter(
                ranges: ranges,
                color: color,
                selected: selected,
                downward: downward,
                labelOf: labelOf,
                labelStyle: AppTextStyles.caption.copyWith(color: color),
                levels: levels,
                progress: progress,
              ),
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
    required this.downward,
    required this.levels,
    required this.progress,
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
  final bool downward;
  final List<double> levels;

  /// How far the bars have opened out, the first leading.
  final double progress;

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
    // The axis holds the targets too; the marks name the readings.
    var axisLow = low;
    var axisHigh = high;
    for (final level in levels) {
      if (level < axisLow) axisLow = level;
      if (level > axisHigh) axisHigh = level;
    }
    final span = (axisHigh - axisLow).abs() < 0.001 ? 1.0 : axisHigh - axisLow;
    final slot = size.width / ranges.length;
    final barWidth = slot * _barShare;
    final top = _labelRoom;
    final bottom = size.height - _labelRoom;
    double xOf(int index) => slot * (index + 0.5);
    double yOf(double value) =>
        top +
        (downward ? value - axisLow : axisHigh - value) / span * (bottom - top);
    final target = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (final level in levels) {
      canvas.drawLine(
        Offset(0, yOf(level)),
        Offset(size.width, yOf(level)),
        target,
      );
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;
    final dimmed = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;
    for (final (index, (bottomValue, topValue)) in known) {
      final middle = (yOf(topValue) + yOf(bottomValue)) / 2;
      final half =
          (yOf(bottomValue) - yOf(topValue)) /
          2 *
          staggeredProgress(progress, index, ranges.length);
      canvas.drawLine(
        Offset(xOf(index), middle - half),
        Offset(xOf(index), middle + half),
        selected == null || selected == index ? paint : dimmed,
      );
    }
    // The extremes are named once the bars stand.
    if (progress < 1) return;

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

    mark(highAt, high, above: !downward);
    mark(lowAt, low, above: downward);
  }

  @override
  bool shouldRepaint(_RangeBarPainter old) =>
      old.ranges != ranges ||
      old.color != color ||
      old.selected != selected ||
      old.downward != downward ||
      old.levels != levels ||
      old.progress != progress;
}

/// A quantity over time from zero up, filled beneath its line: what has
/// happened up to [nowIndex] drawn strong, what is still to come fainter,
/// and a dot on now with a line down to the axis. A [reference] is a
/// level named by [referenceLabel], drawn only while it fits under
/// the curve's peak so it never stretches the axis. [start], [now] and
/// [end] sit under the axis; an end too close to now gives way to it.
/// A modelled curve ([isEstimate], such as caffeine left in the body) is
/// dashed; the [reference] is a thin solid level, as a target is.
class CurveChart extends StatelessWidget {
  const CurveChart({
    super.key,
    required this.values,
    required this.nowIndex,
    required this.color,
    required this.start,
    required this.now,
    required this.end,
    this.reference,
    this.referenceLabel,
    this.height = 120,
    this.isEstimate = false,
  });

  final List<double> values;
  final int nowIndex;
  final Color color;
  final String start;
  final String now;
  final String end;
  final double? reference;
  final String? referenceLabel;
  final double height;
  final bool isEstimate;

  /// How near an end of the axis now may come before that end's label
  /// gives way to now's.
  static const _endRoom = 0.18;

  @override
  Widget build(BuildContext context) {
    final at = values.length < 2 ? 0.0 : nowIndex / (values.length - 1);
    return Column(
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _CurvePainter(
              values: values,
              nowIndex: nowIndex,
              color: color,
              reference: reference,
              referenceLabel: referenceLabel,
              labelStyle: AppTextStyles.caption,
              isEstimate: isEstimate,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Stack(
          children: [
            if (at >= _endRoom)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(start, style: AppTextStyles.caption),
              ),
            // Align puts the label's own point at [at] there; shifting it
            // by the rest centres it under the line.
            Align(
              alignment: Alignment(at * 2 - 1, 0),
              child: FractionalTranslation(
                translation: Offset(at - 0.5, 0),
                child: Text(
                  now,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            if (at <= 1 - _endRoom)
              Align(
                alignment: Alignment.centerRight,
                child: Text(end, style: AppTextStyles.caption),
              ),
          ],
        ),
      ],
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({
    required this.values,
    required this.nowIndex,
    required this.color,
    required this.reference,
    required this.referenceLabel,
    required this.labelStyle,
    required this.isEstimate,
  });

  static const _nowRadius = 4.5;

  final List<double> values;
  final int nowIndex;
  final Color color;
  final double? reference;
  final String? referenceLabel;
  final TextStyle labelStyle;
  final bool isEstimate;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final peak = values.reduce((a, b) => a > b ? a : b);
    if (peak <= 0) return;
    final top = _nowRadius;
    final bottom = size.height;
    double xOf(int index) => index * size.width / (values.length - 1);
    double yOf(double value) => bottom - value / peak * (bottom - top);

    Path lineThrough(int from, int to) {
      final path = Path()..moveTo(xOf(from), yOf(values[from]));
      for (var i = from + 1; i <= to; i++) {
        path.lineTo(xOf(i), yOf(values[i]));
      }
      return path;
    }

    final now = nowIndex.clamp(0, values.length - 1);
    final area = lineThrough(0, values.length - 1)
      ..lineTo(size.width, bottom)
      ..lineTo(0, bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0)],
        ).createShader(Rect.fromLTRB(0, top, size.width, bottom)),
    );

    Paint stroke(double alpha) => Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    Path drawn(Path path) => isEstimate ? _dashed(path) : path;
    if (now > 0) canvas.drawPath(drawn(lineThrough(0, now)), stroke(1));
    if (now < values.length - 1) {
      canvas.drawPath(drawn(lineThrough(now, values.length - 1)), stroke(0.45));
    }

    if (reference case final level? when level > 0 && level <= peak) {
      final y = yOf(level);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = AppColors.textSecondary
          ..strokeWidth = 1,
      );
      if (referenceLabel case final label?) {
        final text = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        // Above the line at the right end, below it when there is no room.
        final above = y - text.height - 2;
        text.paint(
          canvas,
          Offset(size.width - text.width, above >= 0 ? above : y + 2),
        );
      }
    }

    final point = Offset(xOf(now), yOf(values[now]));
    canvas.drawLine(
      Offset(point.dx, 0),
      Offset(point.dx, bottom),
      Paint()
        ..color = AppColors.textSecondary.withValues(alpha: 0.5)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      point,
      _nowRadius + 2,
      Paint()..color = AppColors.surface,
    );
    canvas.drawCircle(point, _nowRadius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.values != values ||
      old.nowIndex != nowIndex ||
      old.color != color ||
      old.reference != reference ||
      old.referenceLabel != referenceLabel ||
      old.isEstimate != isEstimate;
}
