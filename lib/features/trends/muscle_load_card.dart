import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import 'muscle_map.dart';

const _barHeight = 8.0;
const _labelWidth = 56.0;

/// Working sets per muscle per week, most trained first. The point is
/// the shape of the list: what is getting the work, and what is missing
/// from it.
class MuscleLoadCard extends StatelessWidget {
  const MuscleLoadCard({super.key, required this.load});

  final List<(MuscleGroup, int)> load;

  @override
  Widget build(BuildContext context) {
    if (load.isEmpty) {
      return const InfoBanner(message: '還沒有完成的訓練組數，練過之後這裡會列出各肌群的每週組數。');
    }
    final most = load.first.$2;
    return AppCard(
      child: Column(
        children: [
          MuscleMap(setsByMuscle: {for (final (m, sets) in load) m: sets}),
          const SizedBox(height: AppSpacing.sm),
          const _Legend(),
          const Divider(height: AppSpacing.xl),
          for (final (index, (muscle, sets)) in load.indexed) ...[
            if (index > 0) const SizedBox(height: AppSpacing.sm),
            Semantics(
              label: '${muscle.label} 每週 $sets 組',
              excludeSemantics: true,
              child: Row(
                children: [
                  SizedBox(
                    width: _labelWidth,
                    child: Text(muscle.label, style: AppTextStyles.caption),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_barHeight / 2),
                      child: Stack(
                        children: [
                          Container(
                            height: _barHeight,
                            color: AppColors.surfaceRaised,
                          ),
                          FractionallySizedBox(
                            widthFactor: sets / most,
                            child: Container(
                              height: _barHeight,
                              color: index == 0
                                  ? AppColors.training
                                  : AppColors.trainingDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$sets',
                      textAlign: TextAlign.end,
                      style: AppTextStyles.itemTitle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What the shading means, in the same units the list below uses.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '色階由 0 到 $muscleMapTopOfScale 組以上',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (index, stop) in muscleMapLegendStops.indexed) ...[
            if (index > 0) const SizedBox(width: AppSpacing.xxs),
            Container(
              width: 22,
              height: 8,
              decoration: BoxDecoration(
                color: muscleShade(stop),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              stop == muscleMapTopOfScale ? '$stop+' : '$stop',
              style: AppTextStyles.caption,
            ),
          ],
          const SizedBox(width: AppSpacing.xs),
          const Text('組 / 週', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
