import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../backend/engines/training_metrics.dart';
import '../../domain/domain.dart';
import '../../l10n/l10n.dart';
import '../../shared/format.dart';
import '../../shared/widgets/content/elapsed_clock.dart';
import '../../shared/widgets/widgets.dart';

/// `+5 分`, `−1 分`: [label] of the size of [change], with its sign.
String changeLabel(int change, String Function(int size) label) =>
    '${change < 0 ? '−' : '+'}${label(change.abs())}';

/// The minutes the workout's time is moved by, each way.
const _timeAdjustments = [-5, -1, 1, 5];

/// The workout's time so far, large, where it is paused, resumed or
/// corrected for a start that came late or a break that was not one.
Future<void> showWorkoutTimeDialog(BuildContext context) => showAppDialog<void>(
  context,
  AppDialog(
    title: context.l10n.workoutTimeTitle,
    content: const _WorkoutTime(),
    actions: [
      DialogAction(
        label: context.l10n.commonDone,
        tone: DialogTone.primary,
        onTap: () => Navigator.of(context).pop(),
      ),
    ],
  ),
);

class _WorkoutTime extends StatelessWidget {
  const _WorkoutTime();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final store = AppStoreScope.of(context);
    final workout = store.activeWorkout;
    if (workout == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ElapsedClock(
            session: ActiveWorkout(workout),
            builder: (_, elapsed) => Text(
              elapsed,
              style: AppTextStyles.hugeNumber.copyWith(
                color: workout.isPaused
                    ? AppColors.warning
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SecondaryButton(
          label: workout.isPaused ? l10n.commonResume : l10n.commonPause,
          icon: workout.isPaused
              ? Icons.play_arrow_rounded
              : Icons.pause_rounded,
          isCompact: true,
          onPressed: store.togglePause,
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final minutes in _timeAdjustments)
              ChipButton(
                label: changeLabel(
                  minutes,
                  (size) => l10n.durationMinutes(minutes: size),
                ),
                onTap: () => store.adjustElapsed(Duration(minutes: minutes)),
              ),
          ],
        ),
      ],
    );
  }
}

/// How long the rest after a set of [exercise] lasts, and whether it
/// starts by itself when a set is done.
Future<void> showRestTimeDialog(
  BuildContext context, {
  required ExerciseDefinition exercise,
}) => showAppDialog<void>(
  context,
  AppDialog(
    title: context.l10n.restTimeTitle,
    content: _RestTime(exercise: exercise),
    actions: [
      DialogAction(
        label: context.l10n.commonDone,
        tone: DialogTone.primary,
        onTap: () => Navigator.of(context).pop(),
      ),
    ],
  ),
);

class _RestTime extends StatelessWidget {
  const _RestTime({required this.exercise});

  final ExerciseDefinition exercise;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final store = AppStoreScope.of(context);
    final rest = store.restFor(exercise);
    final stepLabel = l10n.durationSeconds(seconds: restStep.inSeconds);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(exercise.name, style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.xs),
        ValueStepper(
          decreaseLabel: l10n.decreaseBy(amount: stepLabel),
          increaseLabel: l10n.increaseBy(amount: stepLabel),
          onDecrease: rest > Duration.zero
              ? () => store.setRestFor(exercise, rest - restStep)
              : null,
          onIncrease: rest < maxRest
              ? () => store.setRestFor(exercise, rest + restStep)
              : null,
          child: StepperReading(value: formatClock(rest)),
        ),
        const SizedBox(height: AppSpacing.md),
        GroupedCard(
          children: [
            SwitchRow(
              title: l10n.autoRestTitle,
              value: store.isAutoRest,
              onChanged: store.setAutoRest,
            ),
            SwitchRow(
              title: l10n.cueSoundTitle,
              value: store.isCueSound,
              onChanged: store.setCueSound,
            ),
          ],
        ),
      ],
    );
  }
}
