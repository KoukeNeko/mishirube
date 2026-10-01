import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/content/elapsed_clock.dart';
import '../../shared/widgets/widgets.dart';
import '../nutrition/daily_nutrition_screen.dart';
import '../training/active_workout_screen.dart';
import '../../l10n/l10n.dart';

/// Today while a workout runs: insights pause, only facts are shown.
List<Widget> buildActiveWorkoutToday(BuildContext context, AppStore store) {
  final workout = store.activeWorkout!;
  return [
    Gutter(
      child: AppCard(
        tone: CardTone.training,
        child: workout.isReady
            ? _ScheduledWorkout(workout: workout)
            : _RunningWorkout(workout: workout),
      ),
    ),
    // Nothing done yet: no row of zeros.
    if (!workout.isReady)
      Gutter(
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.thisSession, style: AppTextStyles.overline),
              const SizedBox(height: AppSpacing.sm),
              StatRow(
                stats: [
                  StatBlock(
                    value: '${workout.completedSets}',
                    label: context.l10n.setsCompleted,
                  ),
                  StatBlock(
                    value:
                        '${workout.completedExercises}/${workout.exercises.length}',
                    label: context.l10n.exerciseProgress,
                  ),
                  StatBlock(
                    value: '${store.workoutReview(workout).records}',
                    label: context.l10n.personalRecords,
                    valueColor: AppColors.training,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    Gutter(child: SectionLabel(context.l10n.otherEntries)),
    Gutter(
      child: AccentRow(
        color: AppColors.nutrition,
        title: context.l10n.moduleNutrition,
        trailing:
            '${context.l10n.mealsCount(count: store.todayMeals.length)} · '
            '~${formatKcal(store.todayKcal)} kcal',
        onTap: () => pushPage(context, const DailyNutritionScreen()),
      ),
    ),
    if (store.weightSummary.latest case final weight?)
      Gutter(
        child: AccentRow(
          color: AppColors.body,
          title: context.l10n.moduleWeight,
          trailing: '${formatWeight(weight.weightKg)} kg',
        ),
      ),
    if (store.lastNight case final night?)
      Gutter(
        child: AccentRow(
          color: AppColors.wellness,
          title: context.l10n.moduleSleep,
          trailing: formatDuration(context.l10n, night.entry.duration),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CategoryLabel(
          label: context.l10n.workoutScheduled,
          color: AppColors.training,
        ),
        const SizedBox(height: AppSpacing.sm),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CategoryLabel(
          label: context.l10n.workoutInProgress,
          color: AppColors.training,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(workout.routineName, style: AppTextStyles.cardTitle),
            ),
            ElapsedClock(
              session: ActiveWorkout(workout),
              builder: (_, elapsed) => Text(
                elapsed,
                style: AppTextStyles.hugeNumber.copyWith(
                  color: AppColors.training,
                ),
              ),
            ),
          ],
        ),
        Text(
          context.l10n.workoutCurrentSet(
            exercise: current.exercise.name,
            set: (current.nextSetIndex ?? current.sets.length - 1) + 1,
            done: workout.completedSets,
          ),
          style: AppTextStyles.caption.copyWith(fontSize: 14),
        ),
        const SizedBox(height: AppSpacing.md),
        ProgressLine(progress: progress),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: context.l10n.backToWorkout,
          onPressed: () => pushPage(context, const ActiveWorkoutScreen()),
        ),
      ],
    );
  }
}
