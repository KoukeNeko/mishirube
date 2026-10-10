import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';

/// One measure of a night: where its reading sits against the measure's
/// usual range.
class NightBandColumn {
  const NightBandColumn({
    required this.measure,
    required this.share,
    required this.label,
  });

  final OvernightMeasure measure;

  /// The night's reading as a share of its usual range's width, 0 on the
  /// lowest and 1 on the highest (`shareInRange`); null for a night with
  /// no reading of it, which leaves the column empty.
  final double? share;

  /// What a screen reader says of it: the name, the reading, the range.
  final String label;

  bool get isOutside => share != null && (share! < 0 || share! > 1);
}

/// A night's readings each as one dot on its own usual range, side by
/// side, so what was read and what was not shows at a glance (see
/// `research/99-sleep-score-and-overnight-vitals.md`). How a graph is
/// drawn changes how people read and feel about health figures (Ancker et
/// al., 2006), so it is neutral: no colour for better or worse.
///
/// The measures share one axis, the usual range being the middle third of
/// it: a position is only "inside it" or "beside it", never better or
/// worse. A dot outside its range is a ring, never another colour, and
/// there is no count of them: with a lowest-to-highest range, one of five
/// readings falls outside by chance on three nights in ten.
class NightBandChart extends StatelessWidget {
  const NightBandChart({super.key, required this.columns});

  final List<NightBandColumn> columns;

  static const _plotHeight = 112.0;
  static const _dotRadius = 6.0;

  /// How far past the range's edge a dot can sit, in range widths; a
  /// reading further out stays at the edge of the plot.
  static const _reach = 0.95;

  static Color _colorOf(OvernightMeasure measure) => switch (measure) {
    OvernightMeasure.respiratoryRate ||
    OvernightMeasure.oxygenSaturation => AppColors.breathing,
    _ => AppColors.heart,
  };

  static IconData _iconOf(OvernightMeasure measure) => switch (measure) {
    OvernightMeasure.heartRate => Icons.favorite_border,
    OvernightMeasure.respiratoryRate ||
    OvernightMeasure.breathingDisturbances => Icons.air,
    OvernightMeasure.oxygenSaturation => Icons.water_drop_outlined,
    OvernightMeasure.wristTemperature ||
    OvernightMeasure.skinTemperatureChange => Icons.thermostat,
    OvernightMeasure.hrvSdnn ||
    OvernightMeasure.hrvRmssd => Icons.monitor_heart_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasOutside = columns.any((column) => column.isOutside);
    final band = AppColors.textSecondary.withValues(alpha: 0.14);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: [
              for (final column in columns)
                if (column.share != null) column.label,
            ].join('. '),
            excludeSemantics: true,
            child: Column(
              children: [
                SizedBox(
                  height: _plotHeight,
                  child: LayoutBuilder(
                    builder: (context, space) => Stack(
                      children: [
                        // The usual range: the middle third of the plot.
                        Positioned(
                          left: 0,
                          right: 0,
                          top: _topOf(1),
                          height: _topOf(0) - _topOf(1),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: band,
                              borderRadius: BorderRadius.circular(
                                AppRadius.small,
                              ),
                            ),
                          ),
                        ),
                        for (final (index, column) in columns.indexed)
                          if (column.share case final share?)
                            Positioned(
                              left:
                                  space.maxWidth /
                                      columns.length *
                                      (index + 0.5) -
                                  _dotRadius,
                              top: _topOf(share) - _dotRadius,
                              child: Container(
                                width: _dotRadius * 2,
                                height: _dotRadius * 2,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: column.isOutside
                                      ? null
                                      : _colorOf(column.measure),
                                  border: column.isOutside
                                      ? Border.all(
                                          color: _colorOf(column.measure),
                                          width: 2,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    for (final column in columns)
                      Expanded(
                        child: Icon(
                          _iconOf(column.measure),
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xxs,
            children: [
              ChartKey(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                label: l10n.usualRange,
              ),
              if (hasOutside)
                ChartKey(
                  color: AppColors.textSecondary,
                  label: l10n.outsideUsual,
                  isRing: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// The distance from the top of the plot of a [share] of a usual
  /// range: the range is the middle third, and above it is higher. A dot
  /// on the lowest or highest position it can have sits whole inside the
  /// plot.
  static double _topOf(double share) {
    final clamped = share.clamp(-_reach, 1 + _reach);
    final fromBottom = (clamped + 1) / 3;
    return _dotRadius + (_plotHeight - 2 * _dotRadius) * (1 - fromBottom);
  }
}
