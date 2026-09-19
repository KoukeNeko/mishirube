import 'package:flutter/material.dart';

import '../../../app/theme.dart';

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
