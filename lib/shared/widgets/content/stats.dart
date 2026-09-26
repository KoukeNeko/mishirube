import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'cards.dart';

/// A big number with an optional unit and a caption underneath.
class StatBlock extends StatelessWidget {
  const StatBlock({
    super.key,
    required this.value,
    this.unit,
    this.label,
    this.valueColor = AppColors.textPrimary,
    this.valueStyle = AppTextStyles.bigNumber,
  });

  final String value;
  final String? unit;
  final String? label;
  final Color valueColor;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueWithUnit(
          value: value,
          unit: unit,
          style: valueStyle.copyWith(color: valueColor),
        ),
        if (label != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(label!, style: AppTextStyles.caption.copyWith(fontSize: 12)),
        ],
      ],
    );
  }
}

class ValueWithUnit extends StatelessWidget {
  const ValueWithUnit({
    super.key,
    required this.value,
    required this.unit,
    this.style = AppTextStyles.bigNumber,
  });

  final String value;
  final String? unit;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: value, style: style),
          if (unit != null)
            TextSpan(
              text: ' $unit',
              style: AppTextStyles.caption.copyWith(
                fontSize: (style.fontSize ?? 16) * 0.42,
              ),
            ),
        ],
      ),
    );
  }
}

/// Evenly spaced row of [StatBlock]s, used by summaries.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.stats});

  final List<StatBlock> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final stat in stats) Expanded(child: stat)],
    );
  }
}

/// One figure of a [FigureGrid]: what it measures, its value and unit,
/// and the colour of what it measures when it has one.
typedef Figure = ({String label, String value, String? unit, Color? color});

/// A detail page's figures in a card, two to a row: each has room for a
/// long number, where a [StatRow] of four would squeeze it.
class FigureGrid extends StatelessWidget {
  const FigureGrid({super.key, required this.figures});

  final List<Figure> figures;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Never below nothing: a first frame can be laid out at zero
          // width.
          final width = ((constraints.maxWidth - AppSpacing.md) / 2).clamp(
            0.0,
            double.infinity,
          );
          return Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (final figure in figures)
                SizedBox(
                  width: width,
                  child: StatBlock(
                    value: figure.value,
                    unit: figure.unit,
                    label: figure.label,
                    valueColor: figure.color ?? AppColors.textPrimary,
                    valueStyle: AppTextStyles.bigNumber.copyWith(fontSize: 26),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Thin rounded progress bar.
class ProgressLine extends StatelessWidget {
  const ProgressLine({
    super.key,
    required this.progress,
    this.color = AppColors.training,
    this.height = 8,
  });

  final double progress;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: progress.clamp(0, 1),
        minHeight: height,
        color: color,
        backgroundColor: AppColors.surfaceRaised,
      ),
    );
  }
}

/// One bar split into [segments] by each one's share of their sum, each
/// in its own colour, with a hairline between them. Only the track shows
/// while there is nothing to split.
class SegmentBar extends StatelessWidget {
  const SegmentBar({super.key, required this.segments, this.height = 12});

  final List<(double, Color)> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final (value, color) in segments)
        if (value > 0) (value, color),
    ];
    final total = shown.fold(0.0, (sum, segment) => sum + segment.$1);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: total <= 0
            ? const ColoredBox(color: AppColors.surfaceRaised)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 2,
                children: [
                  for (final (value, color) in shown)
                    Expanded(
                      flex: (value / total * 1000).round().clamp(1, 1000),
                      child: ColoredBox(color: color),
                    ),
                ],
              ),
      ),
    );
  }
}
