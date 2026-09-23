import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/engines/workout_review.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';

class WorkoutSummaryScreen extends StatelessWidget {
  const WorkoutSummaryScreen({super.key, this.workoutId});

  /// Which finished workout to show; the last one when null.
  final String? workoutId;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final workout = workoutId == null
        ? store.lastFinishedWorkout
        : store.workoutById(workoutId!);
    final footer = PrimaryButton(
      label: '回到今天',
      onPressed: () => returnToTab(context, HomeTab.today),
    );
    if (workout == null) {
      return DetailPage(
        appBar: PageAppBar(title: '訓練'),
        footer: footer,
        children: [
          Gutter(
            child: const EmptyStateCard(
              icon: Icons.fitness_center,
              title: '沒有完成的訓練',
            ),
          ),
        ],
      );
    }
    final finishedAt = workout.finishedAt!;
    final review = store.workoutReview(workout);
    final records = [
      for (final item in review.exercises)
        if (item.record != null) item,
    ];

    return DetailPage(
      appBar: PageAppBar(
        title: workout.routineName,
        subtitle:
            '${workout.startedAt.month} 月 ${workout.startedAt.day} 日 · '
            '${formatTimeOfDay(workout.startedAt)} – '
            '${formatTimeOfDay(finishedAt)}',
      ),
      footer: footer,
      children: [
        Gutter(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatRow(
                  stats: [
                    StatBlock(
                      value: formatClock(workout.elapsedAt(finishedAt)),
                      label: '時長',
                    ),
                    StatBlock(value: '${review.sets}', label: '總組數'),
                    StatBlock(
                      value: formatAmount(review.volumeKg.roundToDouble()),
                      unit: 'kg',
                      label: '總量',
                    ),
                    StatBlock(
                      value: '${review.records}',
                      label: '個人紀錄',
                      valueColor: AppColors.training,
                    ),
                  ],
                ),
                if (_volumeChange(review) case final change?) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TagWrap(labels: [change]),
                ],
              ],
            ),
          ),
        ),
        if (records.isNotEmpty) ...[
          Gutter(child: const SectionLabel('個人紀錄')),
          for (final item in records) Gutter(child: _RecordRow(item: item)),
        ],
        Gutter(child: const SectionLabel('動作')),
        for (final item in review.exercises)
          Gutter(child: _ResultRow(item: item)),
      ],
    );
  }

  /// The total against the same template's last time, when there was one.
  static String? _volumeChange(WorkoutReview review) {
    final previous = review.previousVolumeKg;
    if (previous == null || previous == 0) return null;
    final change = ((review.volumeKg - previous) / previous * 100).round();
    return switch (change) {
      0 => '總量與上次相同',
      > 0 => '總量比上次 +$change%',
      _ => '總量比上次 $change%',
    };
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.item});

  final ExerciseReview item;

  @override
  Widget build(BuildContext context) {
    final record = item.record!;
    return NavCard(
      leading: const Icon(
        Icons.emoji_events_outlined,
        color: AppColors.training,
      ),
      title: item.exercise.name,
      trailing: Text(
        '${formatWeight(record.weightKg)} kg × ${record.reps}',
        style: AppTextStyles.bigNumber.copyWith(fontSize: 20),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.item});

  final ExerciseReview item;

  @override
  Widget build(BuildContext context) {
    final best = item.best;
    return NavCard(
      leading: const AccentBar(color: AppColors.training, height: 32),
      title: item.exercise.name,
      subtitle:
          '${item.sets} 組 · ${formatAmount(item.volumeKg.roundToDouble())} kg',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (best != null)
            Text(
              '${formatWeight(best.weightKg)} kg × ${best.reps}',
              style: AppTextStyles.bigNumber.copyWith(fontSize: 20),
            ),
          if (item.record != null) ...const [
            SizedBox(width: AppSpacing.xs),
            TagChip(label: 'PR', tone: TagTone.solidTraining),
          ],
        ],
      ),
    );
  }
}
