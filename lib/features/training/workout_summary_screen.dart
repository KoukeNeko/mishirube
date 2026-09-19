import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';

/// One line in the summary: an exercise and its best completed set.
class _ExerciseResult {
  const _ExerciseResult({
    required this.name,
    required this.sets,
    required this.topSet,
    required this.isPersonalRecord,
  });

  final String name;
  final int sets;
  final String topSet;
  final bool isPersonalRecord;
}

class WorkoutSummaryScreen extends StatelessWidget {
  const WorkoutSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final workout = store.lastFinishedWorkout;
    final results = workout == null
        ? _plannedResults(store.routine)
        : _actualResults(workout);
    final duration = workout == null
        ? '58:02'
        : formatClock(workout.elapsedAt(workout.finishedAt!));
    final timeRange = workout == null
        ? '19:43 – 20:41'
        : '${formatTimeOfDay(workout.startedAt)} – '
              '${formatTimeOfDay(workout.finishedAt!)}';
    final totalSets = results.fold(0, (sum, result) => sum + result.sets);
    final records = results.where((result) => result.isPersonalRecord).length;

    return DetailPage(
      appBar: PageAppBar(
        title: workout?.routineName ?? store.routine.name,
        subtitle: '9 月 19 日 · $timeRange',
      ),
      footer: PrimaryButton(
        label: '回到今天',
        onPressed: () => returnToTab(context, HomeTab.today),
      ),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatRow(
                stats: [
                  StatBlock(value: duration, label: '時長'),
                  StatBlock(value: '$totalSets', label: '總組數'),
                  StatBlock(
                    value: '$records',
                    label: '新紀錄',
                    valueColor: AppColors.training,
                  ),
                ],
              ),
              if (records > 0) ...const [
                Divider(height: AppSpacing.xxl),
                Text(
                  '槓鈴深蹲 100 kg × 5，估計最大重量從 114 kg 升到 117 kg。',
                  style: AppTextStyles.body,
                ),
                SizedBox(height: AppSpacing.sm),
                TagWrap(labels: ['Epley 公式估計', '非實測']),
              ],
            ],
          ),
        ),
        const SectionLabel('動作'),
        for (final result in results) _ResultRow(result: result),
      ],
    );
  }

  List<_ExerciseResult> _actualResults(WorkoutSession workout) => [
    for (final exercise in workout.exercises)
      if (exercise.completedSets > 0)
        _ExerciseResult(
          name: exercise.exercise.name,
          sets: exercise.completedSets,
          topSet: _topSetLabel(exercise.sets.where((set) => set.isDone)),
          isPersonalRecord: exercise.hasPersonalRecord,
        ),
  ];

  List<_ExerciseResult> _plannedResults(Routine routine) => [
    for (final planned in routine.exercises)
      _ExerciseResult(
        name: planned.exercise.name,
        sets: planned.sets,
        topSet: '${formatWeight(planned.targetWeightKg)} kg × ${planned.reps}',
        isPersonalRecord: planned.exercise.id == 'back-squat',
      ),
  ];

  String _topSetLabel(Iterable<WorkoutSet> sets) {
    final best = sets.reduce((a, b) => a.weightKg >= b.weightKg ? a : b);
    return '${formatWeight(best.weightKg)} kg × ${best.reps}';
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result});

  final _ExerciseResult result;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppRadius.small + 4,
      child: Row(
        children: [
          const AccentBar(color: AppColors.training, height: 32),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.name, style: AppTextStyles.itemTitle),
                Text('${result.sets} 組', style: AppTextStyles.caption),
              ],
            ),
          ),
          Text(
            result.topSet,
            style: AppTextStyles.bigNumber.copyWith(fontSize: 20),
          ),
          if (result.isPersonalRecord) ...const [
            SizedBox(width: AppSpacing.xs),
            TagChip(label: 'PR', tone: TagTone.solidTraining),
          ],
        ],
      ),
    );
  }
}
