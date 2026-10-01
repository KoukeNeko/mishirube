import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'chart_entrance.dart';
import 'chart_scrubber.dart';
import 'charts.dart';

/// A swatch and what it stands for, under a chart.
class ChartKey extends StatelessWidget {
  const ChartKey({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 4,
          decoration: BoxDecoration(
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
