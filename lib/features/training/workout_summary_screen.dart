import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/engines/training_metrics.dart';
import '../../backend/engines/workout_review.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../trends/muscle_map.dart';
import 'edit_workout_screen.dart';
import 'new_routine_screen.dart';
import '../../l10n/l10n.dart';

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
      context.l10n.deletedNamed(name: workout.routineName),
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
        appBar: PageAppBar(title: context.l10n.moduleTraining),
        children: [
          Gutter(
            child: EmptyStateCard(
              icon: Icons.fitness_center,
              title: context.l10n.noFinishedWorkout,
            ),
          ),
        ],
      );
    }
    final finishedAt = workout.finishedAt!;
    final review = store.workoutReview(workout);
    final references = <String, ExerciseHistoryEntry?>{};
    for (final item in review.exercises) {
      references.putIfAbsent(
        item.exercise.id,
        () => relativeLoadReference(
          item.exercise,
          store.exerciseHistory(item.exercise),
          workout.startedAt,
        ),
      );
    }
    final records = [
      for (final item in review.exercises)
        if (item.record != null) item,
    ];

    return DetailPage(
      appBar: PageAppBar(
        title: workout.routineName,
        subtitle:
            '${context.dates.monthDay(workout.startedAt)} · '
            '${formatTimeOfDay(workout.startedAt)}–'
            '${formatTimeOfDay(finishedAt)}',
      ),
      children: [
        Gutter(
          child: FigureGrid(
            figures: [
              (
                label: context.l10n.durationLabel,
                value: formatClock(workout.elapsedAt(finishedAt)),
                unit: null,
                color: null,
              ),
              (
                label: context.l10n.totalSets,
                value: '${review.sets}',
                unit: null,
                color: null,
              ),
              // A volume is weight and reps: a workout of only planks has
              // none, and shows what it did instead.
              if (review.exercises.any(
                (item) => item.exercise.trackingType == TrackingType.weightReps,
              ))
                (
                  label: context.l10n.totalAmount,
                  value: formatKcal(review.volumeKg.round()),
                  unit: 'kg',
                  color: null,
                ),
              if (review.seconds > 0)
                (
                  label: context.l10n.totalTime,
                  value: formatClock(Duration(seconds: review.seconds)),
                  unit: null,
                  color: null,
                ),
              if (review.reps > 0)
                (
                  label: context.l10n.totalReps,
                  value: '${review.reps}',
                  unit: null,
                  color: null,
                ),
              if (review.meters > 0)
                (
                  label: context.l10n.totalDistance,
                  value: formatKilometers(review.meters),
                  unit: 'km',
                  color: null,
                ),
              (
                label: context.l10n.personalRecords,
                value: '${review.records}',
                unit: null,
                color: review.records > 0 ? AppColors.training : null,
              ),
            ],
          ),
        ),
        if (_volumeChange(context.l10n, review) case final change?)
          Gutter(child: TagWrap(labels: [change])),
        PageSection(
          label: context.l10n.workloadSection,
          children: [
            Gutter(
              child: ChipWrap(
                options: Workload.values,
                labelOf: (workload) => workload.labelIn(context.l10n),
                isSelected: (workload) => workload == workout.workload,
                onTap: (workload) => store.rateWorkout(workout, workload),
              ),
            ),
          ],
        ),
        if (records.isNotEmpty)
          PageSection(
            label: context.l10n.personalRecords,
            children: [
              for (final item in records) Gutter(child: _RecordRow(item: item)),
            ],
          ),
        if (review.exercises.isNotEmpty)
          PageSection(
            label: context.l10n.exercisesLabel,
            children: [
              for (final item in review.exercises)
                Gutter(
                  child: _ExerciseResult(
                    item: item,
                    reference: references[item.exercise.id],
                  ),
                ),
            ],
          ),
        if (review.exercises.isNotEmpty)
          PageSection(
            label: context.l10n.trainedAreas,
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
        if (_weekSets(context.l10n, store, review) case final labels
            when labels.isNotEmpty)
          PageSection(
            label: context.l10n.muscleSetsLast7,
            children: [Gutter(child: TagWrap(labels: labels))],
          ),
        // What was done becomes a plan to do again, with its own sets
        // and weights, looked over before it is kept.
        if (workout.completedSets > 0)
          Gutter(
            child: SecondaryButton(
              label: context.l10n.saveAsRoutine,
              icon: Icons.bookmark_add_outlined,
              onPressed: () => pushPage(
                context,
                NewRoutineScreen(planned: store.planFromWorkout(workout)),
              ),
            ),
          ),
        PageSection(
          label: context.l10n.manageSection,
          children: [
            Gutter(
              child: GroupedCard(
                children: [
                  NavRow(
                    title: context.l10n.editThisEntry,
                    onTap: () =>
                        pushPage(context, EditWorkoutScreen(workout: workout)),
                  ),
                  NavRow(
                    title: context.l10n.recordDelete,
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
  static List<String> _weekSets(
    AppLocalizations l10n,
    AppStore store,
    WorkoutReview review,
  ) {
    final trained = {
      for (final item in review.exercises) ...item.exercise.primaryMuscles,
    };
    return [
      for (final (muscle, sets) in store.weekMuscleSets)
        if (trained.contains(muscle))
          l10n.muscleSetCount(muscle: muscle.labelIn(l10n), sets: sets),
    ];
  }

  /// The total against the same template's last time, when there was one.
  static String? _volumeChange(AppLocalizations l10n, WorkoutReview review) {
    final previous = review.previousVolumeKg;
    if (previous == null || previous == 0) return null;
    final change = ((review.volumeKg - previous) / previous * 100).round();
    return switch (change) {
      0 => l10n.volumeSame,
      > 0 => l10n.volumeChangePercent(change: '+$change'),
      _ => l10n.volumeChangePercent(change: '$change'),
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
        record.figuresIn(context.l10n, item.exercise.trackingType),
        style: AppTextStyles.bigNumber.copyWith(fontSize: 20),
      ),
    );
  }
}

/// An exercise as it was done: its sets and total, and each set, the
/// record marked.
class _ExerciseResult extends StatelessWidget {
  const _ExerciseResult({required this.item, required this.reference});

  final ExerciseReview item;
  final ExerciseHistoryEntry? reference;

  String _figuresOf(BuildContext context, WorkoutSet set) =>
      set.figuresIn(context.l10n, item.exercise.trackingType);

  @override
  Widget build(BuildContext context) {
    // Working sets are numbered; the others go by the first character
    // of their kind, as they do while training.
    var ordinal = 0;
    final numbers = [
      for (final set in item.done)
        set.type == SetType.working
            ? '${++ordinal}'
            : set.type.labelIn(context.l10n).characters.first,
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
            context.l10n.setsAndVolume(
              sets: item.sets,
              volume: formatKcal(item.volumeKg.round()),
            ),
            style: AppTextStyles.caption,
          ),
          if (reference case final reference?)
            Text(
              '${context.l10n.estimatedMax} ${formatWeight(reference.oneRepMaxKg!)} kg · '
              '${context.dates.monthDay(reference.date)} · ${context.l10n.epleyEstimate}',
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _figuresOf(context, set),
                          style: AppTextStyles.body.merge(figures),
                        ),
                        if (relativeLoadPercent(set.weightKg, reference)
                            case final percent?)
                          Text(
                            context.l10n.relativeLoadPercent(
                              percent: percent.round(),
                            ),
                            style: AppTextStyles.caption,
                          ),
                      ],
                    ),
                  ),
                  if (identical(set, item.record))
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 18,
                      color: AppColors.training,
                      semanticLabel: context.l10n.personalRecords,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
