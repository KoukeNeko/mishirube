import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../backend/engines/caffeine.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';

/// Caffeine likely still in the body, now and as it falls away, with the
/// bedtime reference dashed across the curve while it fits under it.
class CaffeineCard extends StatelessWidget {
  const CaffeineCard({
    super.key,
    required this.curve,
    required this.nowIndex,
    this.onTap,
    this.action,
    this.chartHeight = 88,
  });

  final List<(DateTime, double)> curve;
  final int nowIndex;

  /// Opens the caffeine page; null on that page itself.
  final VoidCallback? onTap;

  /// Beside the label: on 今天, ending what the lock screen shows.
  final Widget? action;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    final now = curve[nowIndex].$2.round();
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryLabel(
                label: context.l10n.nutrientCaffeine,
                color: AppColors.caffeine,
              ),
              if (action case final action?) ...[const Spacer(), action],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ValueWithUnit(value: '$now', unit: 'mg'),
          Text(
            context.l10n.halfLifeBasis(
              hours: formatAmount(caffeineHalfLifeHours),
            ),
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            label: context.l10n.caffeineRemaining,
            value: '$now mg',
            child: ExcludeSemantics(
              child: CurveChart(
                values: [for (final (_, mg) in curve) mg],
                origin: curve.first.$1,
                step: curve.length < 2
                    ? Duration.zero
                    : curve[1].$1.difference(curve.first.$1),
                nowIndex: nowIndex,
                color: AppColors.caffeine,
                start: formatTimeOfDay(curve.first.$1),
                now: formatTimeOfDay(curve[nowIndex].$1),
                end: formatTimeOfDay(curve.last.$1),
                height: chartHeight,
                isEstimate: true,
                reference: caffeineBedtimeReferenceMg,
                referenceLabel: context.l10n.caffeineReference(
                  mg: formatAmount(caffeineBedtimeReferenceMg),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
