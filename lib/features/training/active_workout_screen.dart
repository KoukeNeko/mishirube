import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../shared/format.dart';
import '../../shared/motion.dart';
import '../../shared/widgets/elapsed_clock.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_picker_screen.dart';
import 'rest_timer_screen.dart';
import 'substitute_exercise_screen.dart';
import 'workout_summary_screen.dart';

/// Starts (or resumes) today's workout and opens the logging screen.
void startWorkoutFlow(BuildContext context) {
  AppStoreScope.read(context).startWorkout();
  pushPage(context, const ActiveWorkoutScreen());
}

class ActiveWorkoutScreen extends StatelessWidget {
  const ActiveWorkoutScreen({super.key});

  void _finish(BuildContext context) {
    AppStoreScope.read(context).finishWorkout();
    replaceWithPage(context, const WorkoutSummaryScreen());
  }

  void _completeSet(BuildContext context, WorkoutSession workout) {
    final store = AppStoreScope.read(context);
    final exercise = workout.currentExercise;
    final completedSetNumber = (exercise.nextSetIndex ?? 0) + 1;
    final completedSet = store.completeNextSet();
    if (completedSet == null) return;
    pushPage(
      context,
      RestTimerScreen(
        exerciseName: exercise.exercise.name,
        completedSet: completedSet,
        isPersonalRecord:
            exercise.isPersonalRecordCandidate && completedSetNumber == 1,
      ),
    );
  }

  Future<void> _addExercises(BuildContext context) async {
    final store = AppStoreScope.read(context);
    final selected = await pushModalPage<List<ExerciseDefinition>>(
      context,
      ExercisePickerScreen(targetName: store.activeWorkout!.routineName),
    );
    if (selected == null || selected.isEmpty) return;
    store.addExercises(selected);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final workout = store.activeWorkout;
    if (workout == null) return const Scaffold();
    final exercise = workout.currentExercise;
    final isWorkoutDone = workout.completedSets == workout.totalSets;
    final media = MediaQuery.of(context);
    // Uses the shared collapsing app bar in its branded variant: a green
    // live hero instead of a large title.
    return EdgeToEdgeScaffold(
      // Measured below the Scaffold so text uses Material's line height.
      body: Builder(
        builder: (context) => CollapsingScrollView(
          header: CollapsingHeaderDelegate(
            toolbar: ToolbarMetrics.of(context),
            topInset: media.padding.top,
            largeHeight: _WorkoutHero.measureHeight(context),
            solidColor: AppColors.trainingSurface,
            isHighContrast: media.highContrast,
            reduceMotion: prefersReducedMotion(context),
            leading: IconButton(
              tooltip: '收合',
              constraints: BoxConstraints.tightFor(
                width: ToolbarMetrics.of(context).actionHitSize,
                height: ToolbarMetrics.of(context).actionHitSize,
              ),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.keyboard_arrow_down, size: 30),
            ),
            actions: [
              HeaderAction(
                icon: Icons.stop_rounded,
                label: '結束',
                semanticLabel: '結束訓練',
                onTap: () => _finish(context),
              ),
            ],
            compactTitle: _LiveTitle(workout: workout),
            large: _WorkoutHero(
              workout: workout,
              onPickExercise: () => _showExerciseList(context, workout),
            ),
          ),
          children: [
            _SuggestionCard(exercise: exercise),
            const _SuggestionTags(),
            const _SetTypeHeader(),
            for (var i = 0; i < exercise.sets.length; i++)
              _SetRow(
                number: i + 1,
                set: exercise.sets[i],
                isCurrent: i == exercise.nextSetIndex,
                onToggle: () => store.toggleSet(i),
              ),
            Row(
              children: [
                Expanded(
                  child: DashedActionCard(
                    label: '加入動作',
                    onTap: () => _addExercises(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: SecondaryButton(
                    label: '替換這個動作',
                    icon: Icons.swap_horiz,
                    isCompact: true,
                    onPressed: () =>
                        pushPage(context, const SubstituteExerciseScreen()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      footer: BottomActionBar(
        caption: '離線也會立刻存進這台裝置',
        child: isWorkoutDone
            ? PrimaryButton(label: '結束並查看摘要', onPressed: () => _finish(context))
            : PrimaryButton(
                label: '完成這一組',
                onPressed: () => _completeSet(context, workout),
              ),
      ),
    );
  }

  void _showExerciseList(BuildContext context, WorkoutSession workout) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            for (var i = 0; i < workout.exercises.length; i++)
              ListTile(
                title: Text(workout.exercises[i].exercise.name),
                subtitle: Text(
                  '${workout.exercises[i].completedSets} / '
                  '${workout.exercises[i].sets.length} 組',
                ),
                selected: i == workout.currentExerciseIndex,
                selectedColor: AppColors.training,
                onTap: () {
                  AppStoreScope.read(context).selectExercise(i);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

const _heroTimerStyle = TextStyle(
  fontSize: 56,
  fontWeight: FontWeight.w800,
  color: AppColors.training,
  letterSpacing: -1,
  fontFeatures: [FontFeature.tabularFigures()],
);
final _heroNameStyle = AppTextStyles.cardTitle.copyWith(fontSize: 30);
const _heroGap = AppSpacing.xs;
const _heroBottomPadding = AppSpacing.lg;

/// Branded live content at the top of the workout: the timer and the
/// current exercise. It scrolls away into [_LiveTitle].
class _WorkoutHero extends StatelessWidget {
  const _WorkoutHero({required this.workout, required this.onPickExercise});

  final WorkoutSession workout;
  final VoidCallback onPickExercise;

  static double measureHeight(BuildContext context) {
    const maxWidth = double.infinity;
    return measureTextHeight(
          context,
          '00:00',
          _heroTimerStyle,
          maxWidth: maxWidth,
        ) +
        _heroGap +
        measureTextHeight(context, '槓', _heroNameStyle, maxWidth: maxWidth) +
        _heroBottomPadding;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        0,
        AppSpacing.screenGutter,
        _heroBottomPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElapsedClock(
            workout: workout,
            // One line that shrinks to fit, even at large text sizes.
            builder: (_, elapsed) => FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(elapsed, maxLines: 1, style: _heroTimerStyle),
            ),
          ),
          const SizedBox(height: _heroGap),
          InkWell(
            onTap: onPickExercise,
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      workout.currentExercise.exercise.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _heroNameStyle,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      '動作 ${workout.currentExerciseIndex + 1} / ${workout.exercises.length}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ),
                  const Icon(Icons.expand_more, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinned live bar once the hero has scrolled away.
class _LiveTitle extends StatelessWidget {
  const _LiveTitle({required this.workout});

  final WorkoutSession workout;

  @override
  Widget build(BuildContext context) {
    final position =
        '${workout.currentExerciseIndex + 1}/${workout.exercises.length}';
    return ElapsedClock(
      workout: workout,
      builder: (_, elapsed) => Text(
        '$elapsed · ${workout.currentExercise.exercise.name} $position',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: compactTitleStyle.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.exercise});

  final ExerciseSession exercise;

  @override
  Widget build(BuildContext context) {
    final firstSet = exercise.sets.first;
    return InfoBanner(
      message:
          '上次 9/16 做了 ${formatWeight(firstSet.previousWeightKg)} kg × '
          '${firstSet.previousReps}${firstSet.rir == null ? '' : '，RIR ${firstSet.rir}'}。'
          '建議這次 ${formatWeight(firstSet.weightKg)} kg × ${firstSet.reps}。',
    );
  }
}

class _SuggestionTags extends StatelessWidget {
  const _SuggestionTags();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        const TagChip(label: '線性進階 +2.5 kg', tone: TagTone.training),
        const TagChip(label: '估計最大重量 114 kg'),
        GestureDetector(
          onTap: () => showToast(context, '由訓練引擎 v0.4 依上次重量、RIR 與線性進階規則計算。'),
          child: const TagChip(label: '這個建議怎麼來的', tone: TagTone.training),
        ),
      ],
    );
  }
}

class _SetTypeHeader extends StatelessWidget {
  const _SetTypeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('組', style: AppTextStyles.overline),
        const Spacer(),
        for (final type in const ['熱身', '遞減', '力竭']) ...[
          const SizedBox(width: AppSpacing.xs),
          GestureDetector(
            onTap: () =>
                showToast(context, '已加入一組「$type」', kind: ToastKind.success),
            child: TagChip(label: type),
          ),
        ],
      ],
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.number,
    required this.set,
    required this.isCurrent,
    required this.onToggle,
  });

  static const _checkSize = 40.0;

  final int number;
  final WorkoutSet set;
  final bool isCurrent;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isUpcoming = !set.isDone && !isCurrent;
    final numberStyle = AppTextStyles.bigNumber.copyWith(
      fontSize: 28,
      color: isUpcoming ? AppColors.textTertiary : AppColors.textPrimary,
    );
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      radius: AppRadius.small + 4,
      borderColor: isCurrent ? AppColors.training : null,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('$number', style: AppTextStyles.itemTitle),
          ),
          Text(
            '上次\n${formatWeight(set.previousWeightKg)} × ${set.previousReps}',
            style: AppTextStyles.caption.copyWith(fontSize: 11, height: 1.3),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                children: [
                  ValueWithUnit(
                    value: formatWeight(set.weightKg),
                    unit: 'kg',
                    style: numberStyle,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ValueWithUnit(
                    value: '${set.reps}',
                    unit: '次',
                    style: numberStyle,
                  ),
                  if (set.isDone && set.rir != null)
                    Text('  RIR ${set.rir}', style: AppTextStyles.caption),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Semantics(
            label: '第 $number 組完成',
            checked: set.isDone,
            child: GestureDetector(
              onTap: onToggle,
              child: CheckSquare(
                isChecked: set.isDone,
                size: _checkSize,
                uncheckedColor: isCurrent
                    ? AppColors.trainingSurface
                    : AppColors.surfaceRaised,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
