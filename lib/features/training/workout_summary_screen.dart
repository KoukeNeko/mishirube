import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/engines/workout_review.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../trends/muscle_map.dart';
import 'edit_workout_screen.dart';
import 'routine_detail_screen.dart';

class WorkoutSummaryScreen extends StatelessWidget {
  const WorkoutSummaryScreen({super.key, this.workoutId});

  /// Which finished workout to show; the last one when null.
  final String? workoutId;

  /// Removed with an undo, like any other record.
  void _delete(BuildContext context, WorkoutSession workout) {
    final store = AppStoreScope.read(context);
    final toast = ToastScope.read(context);
    store.deleteWorkout(workout.id);
    Navigator.of(context).pop();
    toast.showUndo(
      '已刪除「${workout.routineName}」',
      onUndo: () => store.restoreWorkout(workout.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final workout = workoutId == null
        ? store.lastFinishedWorkout
        : store.workoutById(workoutId!);
    if (workout == null) {
      return DetailPage(
        appBar: PageAppBar(title: '訓練'),
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
      children: [
        Gutter(
          child: FigureGrid(
            figures: [
              (
                label: '時長',
                value: formatClock(workout.elapsedAt(finishedAt)),
                unit: null,
                color: null,
              ),
              (label: '總組數', value: '${review.sets}', unit: null, color: null),
              (
                label: '總量',
                value: formatKcal(review.volumeKg.round()),
                unit: 'kg',
                color: null,
              ),
              (
                label: '個人紀錄',
                value: '${review.records}',
                unit: null,
                color: review.records > 0 ? AppColors.training : null,
              ),
            ],
          ),
        ),
        if (_volumeChange(review) case final change?)
          Gutter(child: TagWrap(labels: [change])),
        PageSection(
          label: '這次的負荷',
          children: [
            Gutter(
              child: ChipWrap(
                options: Workload.values,
                labelOf: (workload) => workload.label,
                isSelected: (workload) => workload == workout.workload,
                onTap: (workload) => store.rateWorkout(workout, workload),
              ),
            ),
          ],
        ),
        if (records.isNotEmpty)
          PageSection(
            label: '個人紀錄',
            children: [
              for (final item in records) Gutter(child: _RecordRow(item: item)),
            ],
          ),
        if (review.exercises.isNotEmpty)
          PageSection(
            label: '動作',
            children: [
              for (final item in review.exercises)
                Gutter(child: _ExerciseResult(item: item)),
            ],
          ),
        if (review.exercises.isNotEmpty)
          PageSection(
            label: '訓練部位',
            children: [
              Gutter(
                child: AppCard(
                  child: MuscleRoleMap(
                    primary: [
                      for (final item in review.exercises)
                        ...item.exercise.primaryMuscles,
                    ],
                    secondary: [
                      for (final item in review.exercises)
                        ...item.exercise.secondaryMuscles,
                    ],
                  ),
                ),
              ),
            ],
          ),
        if (_weekSets(store, review) case final labels when labels.isNotEmpty)
          PageSection(
            label: '近 7 天肌群組數',
            children: [Gutter(child: TagWrap(labels: labels))],
          ),
        // What was done becomes a plan to do again, with its own sets
        // and weights.
        if (workout.completedSets > 0)
          Gutter(
            child: SecondaryButton(
              label: '存成課表',
              icon: Icons.bookmark_add_outlined,
              onPressed: () {
                store.saveAsRoutine(workout);
                pushPage(context, const RoutineDetailScreen());
              },
            ),
          ),
        PageSection(
          label: '管理',
          children: [
            Gutter(
              child: GroupedCard(
                children: [
                  NavRow(
                    title: '編輯這筆紀錄',
                    onTap: () =>
                        pushPage(context, EditWorkoutScreen(workout: workout)),
                  ),
                  NavRow(
                    title: '刪除這筆紀錄',
                    isDestructive: true,
                    onTap: () => _delete(context, workout),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The week's working sets for each muscle this workout trained.
  static List<String> _weekSets(AppStore store, WorkoutReview review) {
    final trained = {
      for (final item in review.exercises) ...item.exercise.primaryMuscles,
    };
    return [
      for (final (muscle, sets) in store.weekMuscleSets)
        if (trained.contains(muscle)) '${muscle.label} $sets 組',
    ];
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

/// An exercise as it was done: its sets and total, and each set, the
/// record marked.
class _ExerciseResult extends StatelessWidget {
  const _ExerciseResult({required this.item});

  final ExerciseReview item;

  static String _figuresOf(WorkoutSet set) => switch (set) {
    WorkoutSet(durationSeconds: final seconds?) => formatClock(
      Duration(seconds: seconds),
    ),
    _ => '${formatWeight(set.weightKg)} kg × ${set.reps}',
  };

  @override
  Widget build(BuildContext context) {
    // Working sets are numbered; the others go by the first character
    // of their kind, as they do while training.
    var ordinal = 0;
    final numbers = [
      for (final set in item.done)
        set.type == SetType.working
            ? '${++ordinal}'
            : set.type.label.characters.first,
    ];
    const figures = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.exercise.name, style: AppTextStyles.itemTitle),
              ),
              if (item.record != null)
                const TagChip(label: 'PR', tone: TagTone.solidTraining),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${item.sets} 組 · ${formatKcal(item.volumeKg.round())} kg',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final (index, set) in item.done.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Row(
                children: [
                  SizedBox(
                    width: AppSpacing.xl,
                    child: Text(
                      numbers[index],
                      style: AppTextStyles.caption.merge(figures),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _figuresOf(set),
                      style: AppTextStyles.body.merge(figures),
                    ),
                  ),
                  if (identical(set, item.record))
                    const Icon(
                      Icons.emoji_events_outlined,
                      size: 18,
                      color: AppColors.training,
                      semanticLabel: '個人紀錄',
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
