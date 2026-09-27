import 'package:flutter/material.dart';

import 'trends_view_model.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import 'muscle_map.dart';
import '../../l10n/l10n.dart';

const _barHeight = 8.0;
const _labelWidth = 56.0;

/// Working sets per muscle per week, most trained first. The point is
/// the shape of the list: what is getting the work, and what is missing
/// from it.
class MuscleLoadCard extends StatelessWidget {
  const MuscleLoadCard({
    super.key,
    required this.load,
    required this.figure,
    required this.onFigure,
  });

  final List<(MuscleGroup, int)> load;

  /// Which body the map is drawn on, and changing it.
  final MuscleFigure figure;
  final ValueChanged<MuscleFigure> onFigure;

  @override
  Widget build(BuildContext context) {
    if (load.isEmpty) {
      return InfoBanner(message: context.l10n.noWorkingSets);
    }
    final most = load.first.$2;
    return AppCard(
      child: Column(
        children: [
          MuscleMap(
            setsByMuscle: {for (final (m, sets) in load) m: sets},
            figure: figure,
          ),
          const SizedBox(height: AppSpacing.sm),
          _FigureChoice(selected: figure, onSelect: onFigure),
          const SizedBox(height: AppSpacing.sm),
          const _Legend(),
          const Divider(height: AppSpacing.xl),
          for (final (index, (muscle, sets)) in load.indexed) ...[
            if (index > 0) const SizedBox(height: AppSpacing.sm),
            Semantics(
              label: context.l10n.muscleWeeklySets(
                muscle: muscle.labelIn(context.l10n),
                sets: sets,
              ),
              excludeSemantics: true,
              child: Row(
                children: [
                  SizedBox(
                    width: _labelWidth,
                    child: Text(
                      muscle.labelIn(context.l10n),
                      style: AppTextStyles.caption,
                    ),
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
      label: context.l10n.muscleScaleLabel(top: muscleMapTopOfScale),
      excludeSemantics: true,
      // One line, scaled down where the unit's words run long.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
            Text(context.l10n.setsPerWeek, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

/// Which body the figure is drawn on. It changes nothing about the
/// numbers, so it sits with the drawing rather than in settings.
class _FigureChoice extends StatelessWidget {
  const _FigureChoice({required this.selected, required this.onSelect});

  final MuscleFigure selected;
  final ValueChanged<MuscleFigure> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final figure in MuscleFigure.values) ...[
          if (figure != MuscleFigure.values.first)
            const SizedBox(width: AppSpacing.xs),
          SelectChip(
            label: figure.labelIn(context.l10n),
            isSelected: selected == figure,
            showsSelectionAsOutline: true,
            onTap: () => onSelect(figure),
          ),
        ],
      ],
    );
  }
}
