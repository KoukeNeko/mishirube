import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/motion.dart';
import '../../shared/widgets/content/elapsed_clock.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_picker_screen.dart';
import 'rest_timer_screen.dart';
import 'substitute_exercise_screen.dart';
import 'workout_summary_screen.dart';

/// Starts (or resumes) today's workout and opens the logging screen.
/// Says so and stops when exercise is already being timed: the running
/// session is the user's to end.
void startWorkoutFlow(BuildContext context) {
  if (!AppStoreScope.read(context).startWorkout()) {
    showToast(context, '運動進行中，先結束運動才能開始訓練', kind: ToastKind.warning);
    return;
  }
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
            leading: const AppBarBackButton(
              icon: Icons.keyboard_arrow_down,
              tooltip: '收合',
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
            Gutter(child: _SuggestionCard(exercise: exercise)),
            Gutter(child: const _SuggestionTags()),
            Gutter(child: const _SetTypeHeader()),
            for (var i = 0; i < exercise.sets.length; i++)
              Gutter(
                child: _SetRow(
                  number: i + 1,
                  set: exercise.sets[i],
                  isCurrent: i == exercise.nextSetIndex,
                  onToggle: () => store.toggleSet(i),
                ),
              ),
            Gutter(
              child: Row(
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
            session: ActiveWorkout(workout),
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
      session: ActiveWorkout(workout),
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
        ChipButton(
          label: '這個建議怎麼來的',
          tone: TagTone.training,
          onTap: () => showToast(context, '由訓練引擎 v0.4 依上次重量、RIR 與線性進階規則計算。'),
        ),
      ],
    );
  }
}

class _SetTypeHeader extends StatelessWidget {
  const _SetTypeHeader();

  @override
  Widget build(BuildContext context) {
    // Wraps instead of one row: at large text sizes the chips need the
    // second line rather than overflowing it.
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('組', style: AppTextStyles.overline),
        ChipButton(
          label: '備註',
          semanticLabel: '為這次訓練寫備註',
          onTap: () => _editNotes(context),
        ),
        for (final type in const [
          SetType.warmup,
          SetType.drop,
          SetType.failure,
        ])
          ChipButton(
            label: type.kindLabel,
            semanticLabel: '加入一組${type.kindLabel}',
            onTap: () => _addSet(context, type),
          ),
      ],
    );
  }
}

/// Asks for a note on the workout; it is kept with the record, not with
/// the template.
Future<void> _editNotes(BuildContext context) async {
  final store = AppStoreScope.read(context);
  final controller = TextEditingController(
    text: store.activeWorkout?.notes ?? '',
  );
  final notes = await showAppDialog<String>(
    context,
    AppDialog(
      title: '這次訓練的備註',
      content: AppTextField(
        controller: controller,
        autofocus: true,
        maxLines: 3,
        hint: '例如：睡不好，握力先到極限',
      ),
      actions: (dialogContext) => [
        PrimaryButton(
          label: '儲存',
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
        ),
        SecondaryButton(
          label: '取消',
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    ),
  );
  controller.dispose();
  if (notes == null || !context.mounted) return;
  store.setWorkoutNotes(notes.trim());
  showToast(context, notes.trim().isEmpty ? '已清除備註' : '已存入備註');
}

/// Adds a set and says what it starts at, since the weight is a default.
void _addSet(BuildContext context, SetType type) {
  final set = AppStoreScope.read(context).addSet(type);
  if (set == null) return;
  showToast(
    context,
    '已加入一組${type.kindLabel} · ${formatWeight(set.weightKg)} kg',
    kind: ToastKind.success,
  );
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
            child: set.type == SetType.working
                ? Text('$number', style: AppTextStyles.itemTitle)
                : Text(
                    set.type.label.characters.first,
                    style: AppTextStyles.itemTitle.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    semanticsLabel: set.type.label,
                  ),
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
