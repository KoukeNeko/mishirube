import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/view_model.dart';
import '../../backend/engines/trend_engine.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import 'trends_view_model.dart';
import '../../l10n/l10n.dart';

/// Weeks before this one that the usual range is read from.
const _usualWeeks = 4;

/// Working sets per muscle, week by week: this week against what the
/// weeks before it usually came to, not against a textbook target.
class MuscleTrendsScreen extends StatelessWidget {
  const MuscleTrendsScreen({super.key});

  @override
  Widget build(BuildContext context) => ViewModelBuilder(
    create: TrendsViewModel.new,
    builder: (context, trends) {
      final muscles = trends.muscleWeeks();
      return DetailPage(
        appBar: PageAppBar(
          title: context.l10n.musclesTitle,
          subtitle: context.l10n.weeklySetsLast8,
        ),
        children: [
          if (muscles.isEmpty)
            Gutter(
              child: EmptyStateCard(
                icon: Icons.accessibility_new,
                title: context.l10n.noWorkingSets,
              ),
            )
          else
            for (final (muscle, weeks) in muscles)
              Gutter(
                child: _MuscleCard(muscle: muscle, weeks: weeks),
              ),
        ],
      );
    },
  );
}

class _MuscleCard extends StatelessWidget {
  const _MuscleCard({required this.muscle, required this.weeks});

  final MuscleGroup muscle;
  final List<WeeklyBar> weeks;

  /// The lowest and highest of the finished weeks just before this one;
  /// null before there are any with sets.
  (int, int)? get _usual {
    final before = weeks
        .take(weeks.length - 1)
        .toList()
        .reversed
        .take(_usualWeeks)
        .map((week) => week.$2)
        .where((sets) => sets > 0)
        .toList();
    if (before.isEmpty) return null;
    return (
      before.reduce((a, b) => a < b ? a : b),
      before.reduce((a, b) => a > b ? a : b),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usual = _usual;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  muscle.labelIn(context.l10n),
                  style: AppTextStyles.itemTitle,
                ),
              ),
              ValueWithUnit(
                value: '${weeks.last.$2}',
                unit: context.l10n.setsThisWeekUnit,
                style: AppTextStyles.bigNumber.copyWith(fontSize: 22),
              ),
            ],
          ),
          if (usual != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              context.l10n.priorWeeksSets(
                weeks: _usualWeeks,
                sets: usual.$1 == usual.$2
                    ? '${usual.$1}'
                    : '${usual.$1}–${usual.$2}',
              ),
              style: AppTextStyles.caption,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            label: context.l10n.muscleSetsChart(
              muscle: muscle.labelIn(context.l10n),
              sets: joinList(context.l10n, weeks.map((week) => '${week.$2}')),
            ),
            excludeSemantics: true,
            child: MiniBarChart(bars: weeks, height: 56),
          ),
        ],
      ),
    );
  }
}
