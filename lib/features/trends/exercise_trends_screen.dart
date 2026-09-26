import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../app/view_model.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_detail_screen.dart';
import 'trends_view_model.dart';

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
        appBar: PageAppBar(title: '動作'),
        children: [
          if (exercises.isEmpty)
            Gutter(
              child: const EmptyStateCard(
                icon: Icons.fitness_center,
                title: '沒有紀錄',
              ),
            )
          else ...[
            for (final (exercise, history) in exercises)
              Gutter(
                child: _ExerciseCard(exercise: exercise, history: history),
              ),
            Gutter(child: const TagWrap(labels: ['Epley 估計'])),
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
              if (estimates.isNotEmpty) '估計最大重量 ${estimates.last.round()} kg',
              '${history.sessionCount} 次',
              '上次 ${last.date.month} 月 ${last.date.day} 日 '
                  '${formatWeight(last.weightKg)} kg × ${last.reps}',
            ].join(' · '),
            style: AppTextStyles.caption,
          ),
          if (estimates.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              label: '估計最大重量走勢，${estimates.length} 次訓練',
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
