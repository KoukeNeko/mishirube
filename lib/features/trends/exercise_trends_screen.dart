import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../app/view_model.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_detail_screen.dart';
import 'trends_view_model.dart';
import '../../l10n/l10n.dart';

/// Each trained exercise's estimated max over its sessions, the most
/// recently trained first; one opens its history and records.
class ExerciseTrendsScreen extends StatelessWidget {
  const ExerciseTrendsScreen({super.key});

  @override
  Widget build(BuildContext context) => ViewModelBuilder(
    create: TrendsViewModel.new,
    builder: (context, trends) {
      final exercises = trends.exerciseHistories();
      return DetailPage(
        appBar: PageAppBar(title: context.l10n.exercisesLabel),
        children: [
          if (exercises.isEmpty)
            Gutter(
              child: EmptyStateCard(
                icon: Icons.fitness_center,
                title: context.l10n.noEntriesShort,
              ),
            )
          else ...[
            for (final (exercise, history) in exercises)
              Gutter(
                child: _ExerciseCard(exercise: exercise, history: history),
              ),
            Gutter(child: TagWrap(labels: [context.l10n.epleyEstimate])),
          ],
        ],
      );
    },
  );
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise, required this.history});

  final ExerciseDefinition exercise;
  final ExerciseHistory history;

  @override
  Widget build(BuildContext context) {
    final last = history.last!;
    final estimates = [
      for (final entry in history.recent.reversed) ?entry.oneRepMaxKg,
    ];
    return AppCard(
      onTap: () => pushPage(context, ExerciseDetailScreen(exercise: exercise)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exercise.name, style: AppTextStyles.itemTitle),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            [
              if (estimates.isNotEmpty)
                context.l10n.estimatedMaxValue(weight: estimates.last.round()),
              context.l10n.timesCount(count: history.sessionCount),
              context.l10n.lastSetOn(
                date: context.dates.monthDay(last.date),
                set: last.figuresIn(context.l10n, exercise.trackingType),
              ),
            ].join(' · '),
            style: AppTextStyles.caption,
          ),
          if (estimates.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              label: context.l10n.estimatedMaxTrend(count: estimates.length),
              excludeSemantics: true,
              child: Sparkline(
                values: estimates,
                color: AppColors.training,
                height: 40,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
