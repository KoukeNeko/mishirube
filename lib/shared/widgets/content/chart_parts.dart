import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'chart_entrance.dart';
import 'chart_scrubber.dart';
import '../controls/chips.dart';
import 'charts.dart';

/// A swatch and what it stands for, under a chart.
class ChartKey extends StatelessWidget {
  const ChartKey({
    super.key,
    required this.color,
    required this.label,
    this.isRing = false,
  });

  final Color color;
  final String label;

  /// A hollow ring, for points a chart rings, rather than a swatch.
  final bool isRing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isRing ? 8 : 12,
          height: isRing ? 8 : 4,
          decoration: isRing
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5),
                )
              : BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

/// How many days (or nights, or weeks) fell into each stretch of a
/// figure, as capsule bars a finger can read: [labels] name the
/// stretches under their bars, [unit] says what they are measured in,
/// and [readoutOf] says a stretch's count.
class DistributionChart extends StatelessWidget {
  const DistributionChart({
    super.key,
    required this.labels,
    required this.counts,
    required this.unit,
    required this.color,
    required this.idle,
    required this.countLabel,
  });

  final List<String> labels;
  final List<int> counts;
  final String unit;
  final Color color;

  /// What the reading line says with no stretch picked.
  final String idle;

  /// A count as the reading says it: `12 晚`.
  final String Function(int count) countLabel;

  @override
  Widget build(BuildContext context) {
    // The most common stretch stands out, as the one to read first.
    final most = counts.indexed.reduce((a, b) => b.$2 > a.$2 ? b : a).$1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChartScrubber(
          count: counts.length,
          indexAt: ChartScrubber.slots(counts.length),
          idle: idle,
          readoutOf: (index) =>
              '${labels[index]} $unit · ${countLabel(counts[index])}',
          builder: (context, selected) => MiniBarChart(
            bars: [
              for (final (index, count) in counts.indexed)
                (labels[index], count),
            ],
            height: 96,
            color: color,
            dimColor: color.withValues(alpha: 0.4),
            selected: selected ?? most,
            highlightsLast: false,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(unit, textAlign: TextAlign.end, style: AppTextStyles.caption),
      ],
    );
  }
}

/// Week after week against a goal: a capsule bar a week, the goal as a
/// line across, and a check on each week that met it. Which weeks met
/// it is the caller's to say, as for [MiniBarChart].
class GoalWeeksChart extends StatelessWidget {
  const GoalWeeksChart({
    super.key,
    required this.values,
    required this.goal,
    required this.met,
    required this.color,
    required this.idle,
    required this.readoutOf,
    this.height = 120,
  });

  /// Each week's figure, oldest first, the week in progress last; null
  /// for a week the goal did not apply to.
  final List<int?> values;
  final int goal;
  final Set<int> met;
  final Color color;
  final String idle;
  final String Function(int index) readoutOf;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ChartScrubber(
      count: values.length,
      indexAt: ChartScrubber.slots(values.length),
      idle: idle,
      readoutOf: readoutOf,
      builder: (context, selected) => MiniBarChart(
        bars: [for (final value in values) ('', value)],
        height: height,
        showLabels: false,
        color: color,
        dimColor: color.withValues(alpha: 0.45),
        selected: selected,
        goal: goal,
        met: met,
      ),
    );
  }
}

/// One part's [share] of a whole, from 0 to 1, as a capsule filled from
/// the left, with a [reference] share (an average, say) as a thin line
/// across it: how a night's stage stands against the usual one.
class ShareBar extends StatelessWidget {
  const ShareBar({
    super.key,
    required this.share,
    required this.color,
    this.reference,
  });

  static const _height = 16.0;

  /// How far the reference line reaches past the bar, above and below.
  static const _overhang = 4.0;

  final double share;
  final Color color;
  final double? reference;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: _height + 2 * _overhang,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: _overhang,
                height: _height,
                child: const DecoratedBox(
                  decoration: ShapeDecoration(
                    color: AppColors.surfaceRaised,
                    shape: StadiumBorder(),
                  ),
                ),
              ),
              if (share > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  top: _overhang,
                  height: _height,
                  // The fill runs in from the left.
                  child: ChartEntrance(
                    shows: [share],
                    builder: (context, progress) => Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        height: _height,
                        // At least round, so a sliver still reads as a
                        // capsule.
                        width:
                            (width *
                                    share.clamp(0.0, 1.0) *
                                    easedProgress(progress))
                                .clamp(_height, width),
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            color: color,
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (reference case final reference?)
                Positioned(
                  left: (width * reference.clamp(0.0, 1.0) - 1).clamp(
                    0.0,
                    width - 2,
                  ),
                  top: 0,
                  bottom: 0,
                  width: 2,
                  child: const ColoredBox(color: AppColors.textPrimary),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A figure day by day, or week by week, against what is usual for the
/// person: the line, a band that moves with the days ([bands], each
/// slot's own usual range, null before there is one), slots apart from
/// it ringed rather than coloured, a reading for each slot with its
/// range in the band's key, and [summary] at rest, such as how many days
/// sat within it.
class UsualRangeTrend extends StatelessWidget {
  const UsualRangeTrend({
    super.key,
    this.label,
    required this.color,
    required this.days,
    required this.values,
    required this.bands,
    required this.format,
    required this.formatRange,
    required this.usualLabel,
    required this.outsideLabel,
    required this.usualValue,
    required this.noValue,
    required this.readoutDay,
    this.summary,
    this.semanticLabel,
    this.height = 96,
  });

  /// What it measures; none where the page already names it.
  final String? label;
  final Color color;

  /// Each slot's day, or its week's first, oldest first, aligned with
  /// [values] and [bands]; a slot without a figure is a null value and a
  /// gap in the line.
  final List<DateTime> days;
  final List<double?> values;
  final List<(double, double)?> bands;

  /// A value, and a range of them, as the page writes them, with the
  /// unit once: `62 次/分`, `52–68 次/分`.
  final String Function(double value) format;
  final String Function(double low, double high) formatRange;

  /// The legend's names for the band and the ringed points, `平常範圍`
  /// and `範圍外`; a reading's range, `平常 52–68 次/分`; and a day
  /// without a figure.
  final String usualLabel;
  final String outsideLabel;
  final String Function(String range) usualValue;
  final String noValue;

  /// A slot as a reading names it.
  final String Function(DateTime day) readoutDay;
  final String? summary;

  /// What a screen reader says the chart is.
  final String? semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final outside = {
      for (final (index, value) in values.indexed)
        if ((value, bands[index]) case (final figure?, (final low, final high))
            when figure < low || figure > high)
          index,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label case final label?) ...[
          CategoryLabel(label: label, color: color),
          const SizedBox(height: AppSpacing.sm),
        ],
        Semantics(
          label: semanticLabel,
          child: ChartScrubber(
            count: values.length,
            indexAt: ChartScrubber.points(values.length),
            idle: summary ?? '',
            readoutOf: (index) => [
              readoutDay(days[index]),
              switch (values[index]) {
                final value? => format(value),
                null => noValue,
              },
            ].join(' · '),
            // The picked day's range is named by the band's own key: the
            // reading line has no room for it.
            builder: (context, selected) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Sparkline(
                  values: values,
                  color: color,
                  height: height,
                  selected: selected,
                  bands: bands,
                  outside: outside,
                ),
                if (bands.any((band) => band != null)) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.xxs,
                    children: [
                      ChartKey(
                        color: AppColors.textSecondary.withValues(alpha: 0.3),
                        label: switch (selected == null
                            ? null
                            : bands[selected]) {
                          (final low, final high) => usualValue(
                            formatRange(low, high),
                          ),
                          null => usualLabel,
                        },
                      ),
                      if (outside.isNotEmpty)
                        ChartKey(
                          color: color,
                          label: outsideLabel,
                          isRing: true,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A word-sized row of [ranges], one capsule a slot from its low to its
/// high end, beside a figure in a list: a day's lowest to highest heart
/// rate, or a blood pressure's diastolic to systolic. A slot without one
/// is left empty. No axis or labels; the page the row opens has them.
class RangeSpark extends StatelessWidget {
  const RangeSpark({
    super.key,
    required this.ranges,
    required this.color,
    this.width = 96,
    this.height = 28,
  });

  final List<(double, double)?> ranges;
  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    // Each capsule opens out from its middle, one after another, as the
    // full range chart's bars do.
    child: ChartEntrance(
      shows: ranges,
      builder: (context, progress) => CustomPaint(
        painter: _RangeSparkPainter(
          ranges: ranges,
          color: color,
          progress: progress,
        ),
      ),
    ),
  );
}

class _RangeSparkPainter extends CustomPainter {
  _RangeSparkPainter({
    required this.ranges,
    required this.color,
    required this.progress,
  });

  static const _barWidth = 4.0;

  final List<(double, double)?> ranges;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final known = ranges.nonNulls.toList();
    if (known.isEmpty) return;
    var low = known.first.$1;
    var high = known.first.$2;
    for (final (bottom, top) in known) {
      if (bottom < low) low = bottom;
      if (top > high) high = top;
    }
    final span = (high - low).abs() < 0.001 ? 1.0 : high - low;
    final slot = size.width / ranges.length;
    const inset = _barWidth / 2;
    double yOf(double value) => (high - low).abs() < 0.001
        ? size.height / 2
        : inset + (high - value) / span * (size.height - _barWidth);
    final paint = Paint()
      ..color = color
      ..strokeWidth = _barWidth
      ..strokeCap = StrokeCap.round;
    for (final (index, range) in ranges.indexed) {
      if (range == null) continue;
      final (bottom, top) = range;
      final shown = staggeredProgress(progress, index, ranges.length);
      if (shown <= 0) continue;
      final middle = (yOf(bottom) + yOf(top)) / 2;
      final half = (yOf(bottom) - yOf(top)) / 2 * shown;
      final x = slot * (index + 0.5);
      canvas.drawLine(
        Offset(x, middle - half),
        Offset(x, middle + half),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RangeSparkPainter old) =>
      old.ranges != ranges || old.color != color || old.progress != progress;
}
