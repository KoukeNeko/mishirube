import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/content/elapsed_clock.dart';
import '../../shared/widgets/widgets.dart';
import '../nutrition/daily_nutrition_screen.dart';
import 'today_widgets.dart';
import '../training/active_workout_screen.dart';
import '../../l10n/l10n.dart';

/// Today while a workout runs: insights pause, only facts are shown.
List<Widget> buildActiveWorkoutToday(BuildContext context, AppStore store) {
  final workout = store.activeWorkout!;
  final records = store.workoutReview(workout).records;
  Segment stat(String label, String value) => Segment(
    child: SegmentStat(
      label: label,
      color: AppColors.training,
      placeholder: '—',
      value: value,
    ),
  );
  return [
    Gutter(
      child: CategoryGroup(
        label: workout.isReady
            ? context.l10n.workoutScheduled
            : context.l10n.workoutInProgress,
        color: AppColors.training,
        children: [
          // The records light up as one is set, and again for the next.
          ChartEntrance(
            shows: [records],
            builder: (context, drawn) => SegmentedGroup(
              rows: [
                [
                  Segment(
                    surface: AppColors.surfaceRaised,
                    child: workout.isReady
                        ? _ScheduledWorkout(workout: workout)
                        : _RunningWorkout(workout: workout),
                  ),
                ],
                // Nothing done yet: no row of zeros.
                if (!workout.isReady)
                  [
                    stat(
                      context.l10n.setsCompleted,
                      '${workout.completedSets}',
                    ),
                    stat(
                      context.l10n.exerciseProgress,
                      '${workout.completedExercises}/${workout.exercises.length}',
                    ),
                    personalRecordsSegment(context, records, drawn),
                  ],
              ],
            ),
          ),
        ],
      ),
    ),
    Gutter(
      child: CategoryGroup(
        label: context.l10n.otherEntries,
        color: AppColors.textSecondary,
        children: [
          SegmentedGroup(
            rows: [
              [
                Segment(
                  onTap: () => pushPage(context, const DailyNutritionScreen()),
                  child: SegmentRow(
                    leading: const AccentBar(color: AppColors.nutrition),
                    title: context.l10n.moduleNutrition,
                    value:
                        '${context.l10n.mealsCount(count: store.todayMeals.length)} · '
                        '${formatKcal(store.todayKcal)} kcal',
                  ),
                ),
              ],
              if (store.weightSummary.latest case final weight?)
                [
                  Segment(
                    child: SegmentRow(
                      leading: const AccentBar(color: AppColors.body),
                      title: context.l10n.moduleWeight,
                      value: '${formatWeight(weight.weightKg)} kg',
                    ),
                  ),
                ],
              if (store.lastNight case final night?)
                [
                  Segment(
                    child: SegmentRow(
                      leading: const AccentBar(color: AppColors.wellness),
                      title: context.l10n.moduleSleep,
                      value: formatDuration(context.l10n, night.entry.duration),
                    ),
                  ),
                ],
            ],
          ),
        ],
      ),
    ),
  ];
}

/// A workout that is arranged and waiting: what it is made of, and the
/// way to start it or to look it over first.
class _ScheduledWorkout extends StatelessWidget {
  const _ScheduledWorkout({required this.workout});

  final WorkoutSession workout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: segmentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(workout.routineName, style: AppTextStyles.cardTitle),
          Text(
            context.l10n.routineSummary(
              exercises: workout.exercises.length,
              sets: workout.totalSets,
            ),
            style: AppTextStyles.caption.copyWith(fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: context.l10n.startExercising,
            icon: Icons.play_arrow_outlined,
            onPressed: () {
              AppStoreScope.read(context).beginWorkout();
              pushPage(context, const ActiveWorkoutScreen());
            },
          ),
          LinkText(
            label: context.l10n.commonView,
            onTap: () => pushPage(context, const ActiveWorkoutScreen()),
          ),
        ],
      ),
    );
  }
}

/// A workout under way: its clock, where it is, and the way back to it.
class _RunningWorkout extends StatelessWidget {
  const _RunningWorkout({required this.workout});

  final WorkoutSession workout;

  @override
  Widget build(BuildContext context) {
    final current = workout.currentExercise;
    final progress = workout.totalSets == 0
        ? 0.0
        : workout.completedSets / workout.totalSets;
    return Padding(
      padding: segmentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            workout.routineName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
          ElapsedClock(
            session: ActiveWorkout(workout),
            builder: (_, elapsed) => MetricValue(value: elapsed, size: 44),
          ),
          Text(
            context.l10n.workoutCurrentSet(
              exercise: current.exercise.name,
              set: (current.nextSetIndex ?? current.sets.length - 1) + 1,
              done: workout.completedSets,
            ),
            style: AppTextStyles.caption.copyWith(fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.sm),
          ThickProgress(
            progress: progress,
            color: AppColors.training,
            drawsIn: false,
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: context.l10n.backToWorkout,
            onPressed: () => pushPage(context, const ActiveWorkoutScreen()),
          ),
        ],
      ),
    );
  }
}
