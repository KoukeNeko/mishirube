import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/haptics.dart';
import '../../shared/motion.dart';
import '../../shared/widgets/content/elapsed_clock.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_picker_screen.dart';
import '../shell/finish_session_dialog.dart';
import 'rest_timer_screen.dart';
import 'set_editor_dialog.dart';
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

  /// Ends the workout from its header. With every set done that is the
  /// footer's answer; with sets left it asks first.
  Future<void> _end(BuildContext context, WorkoutSession workout) async {
    if (workout.completedSets == workout.totalSets) return _finish(context);
    final store = AppStoreScope.read(context);
    final choice = await askHowSessionEnds(context, ActiveWorkout(workout));
    if (!context.mounted) return;
    switch (choice) {
      case null || FinishChoice.keepGoing:
        return;
      case FinishChoice.finish:
        _finish(context);
      case FinishChoice.discard:
        store.discardWorkout();
        Navigator.of(context).maybePop();
        showToast(context, '已放棄這次訓練');
    }
  }

  void _completeSet(BuildContext context, WorkoutSession workout) {
    final store = AppStoreScope.read(context);
    final exercise = workout.currentExercise;
    final completedSet = store.completeNextSet();
    if (completedSet == null) return;
    store.startRest(exercise.exercise);
    pushPage(
      context,
      RestTimerScreen(
        exerciseName: exercise.exercise.name,
        completedSet: completedSet,
        isPersonalRecord: store.isPersonalRecord(completedSet),
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
                onTap: () => _end(context, workout),
              ),
            ],
            compactTitle: _LiveTitle(workout: workout),
            large: _WorkoutHero(
              workout: workout,
              onPickExercise: () => _showExerciseList(context, workout),
            ),
          ),
          children: [
            if (store.restEndsAt != null) Gutter(child: const _RestBanner()),
            if (store.exerciseHistory(exercise.exercise)
                case ExerciseHistory(last: final last?) && final history)
              Gutter(
                child: _LastTime(
                  last: last,
                  oneRepMaxKg: history.estimatedOneRepMaxKg,
                ),
              ),
            Gutter(child: const _SetTypeHeader()),
            for (var i = 0; i < exercise.sets.length; i++)
              Gutter(
                child: _SetRow(
                  ordinal: _ordinal(exercise.sets, i),
                  set: exercise.sets[i],
                  isCurrent: i == exercise.nextSetIndex,
                  onToggle: () => store.toggleSet(i),
                  onEdit: () => _editSet(
                    context,
                    i,
                    exercise.sets[i],
                    _setName(exercise.sets[i], _ordinal(exercise.sets, i)),
                  ),
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
        child: isWorkoutDone
            ? PrimaryButton(label: '結束並儲存', onPressed: () => _finish(context))
            : PrimaryButton(
                label: '完成這一組',
                onPressed: () => _completeSet(context, workout),
              ),
      ),
    );
  }

  /// A working set's number among the working sets, since warm-ups come
  /// first; null for any other kind of set.
  static int? _ordinal(List<WorkoutSet> sets, int index) {
    if (sets[index].type != SetType.working) return null;
    return sets
        .take(index + 1)
        .where((item) => item.type == SetType.working)
        .length;
  }

  Future<void> _editSet(
    BuildContext context,
    int index,
    WorkoutSet set,
    String name,
  ) async {
    final store = AppStoreScope.read(context);
    final edit = await showSetEditor(
      context,
      title: name,
      set: set,
      equipment: store.activeWorkout!.currentExercise.exercise.equipment,
    );
    switch (edit) {
      case SetChanged(:final weightKg, :final reps, :final rir):
        store.editSet(index, weightKg: weightKg, reps: reps, rir: rir);
      case SetRemoved():
        store.removeSet(index);
      case null:
        break;
    }
  }

  void _showExerciseList(BuildContext context, WorkoutSession workout) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          AppSpacing.screenGutter,
          AppSpacing.screenGutter,
          AppSpacing.screenGutter + MediaQuery.paddingOf(sheetContext).bottom,
        ),
        children: [
          const SectionLabel('動作'),
          for (final (i, item) in workout.exercises.indexed)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: RadioRow(
                title: item.exercise.name,
                subtitle: '${item.completedSets} / ${item.sets.length} 組',
                isSelected: i == workout.currentExerciseIndex,
                onTap: () {
                  AppStoreScope.read(context).selectExercise(i);
                  Navigator.of(sheetContext).pop();
                },
              ),
            ),
        ],
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

/// The rest still running after its page was left: the time left, and
/// the two answers to it.
class _RestBanner extends StatefulWidget {
  const _RestBanner();

  @override
  State<_RestBanner> createState() => _RestBannerState();
}

class _RestBannerState extends State<_RestBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTick() {
    if (AppStoreScope.read(context).settleRest()) {
      AppHaptics.alert();
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final endsAt = store.restEndsAt;
    if (endsAt == null) return const SizedBox.shrink();
    final remaining = endsAt.difference(store.now());
    return AppCard(
      tone: CardTone.training,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '休息 ${formatClock(remaining.isNegative ? Duration.zero : remaining)}',
              style: AppTextStyles.cardTitle.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          ChipButton(
            label: '+30 秒',
            onTap: () => store.extendRest(const Duration(seconds: 30)),
          ),
          const SizedBox(width: AppSpacing.xs),
          ChipButton(
            label: '跳過',
            tone: TagTone.training,
            onTap: store.skipRest,
          ),
        ],
      ),
    );
  }
}

/// `第 2 組`, or the kind of set it is: `熱身組`.
String _setName(WorkoutSet set, int? ordinal) =>
    ordinal == null ? set.type.label : '第 $ordinal 組';

/// The exercise as it went last time, from the records: what the sets
/// on this page are measured against.
class _LastTime extends StatelessWidget {
  const _LastTime({required this.last, required this.oneRepMaxKg});

  final ExerciseHistoryEntry last;
  final double? oneRepMaxKg;

  @override
  Widget build(BuildContext context) {
    final date = last.date;
    final estimate = oneRepMaxKg;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '上次 ${date.month} 月 ${date.day} 日 · '
          '${formatWeight(last.weightKg)} kg × ${last.reps}'
          '${last.rir == null ? '' : ' · RIR ${last.rir}'}',
          style: AppTextStyles.caption,
        ),
        if (estimate != null)
          TagChip(
            label: '估計最大重量 ${estimate.round()} kg',
            tone: TagTone.training,
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
  final notes = await showTextDialog(
    context,
    title: '這次訓練的備註',
    initial: store.activeWorkout?.notes ?? '',
    hint: '例如：睡不好，握力先到極限',
    maxLines: 3,
  );
  if (notes == null || !context.mounted) return;
  store.setWorkoutNotes(notes.trim());
  showToast(context, notes.trim().isEmpty ? '已清除備註' : '已更新備註');
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
    required this.ordinal,
    required this.set,
    required this.isCurrent,
    required this.onToggle,
    required this.onEdit,
  });

  static const _checkSize = 40.0;

  /// Its number among the working sets; null for a warm-up, drop or
  /// failure set, which is shown by its kind.
  final int? ordinal;
  final WorkoutSet set;
  final bool isCurrent;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final name = _setName(set, ordinal);
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
                ? Text('$ordinal', style: AppTextStyles.itemTitle)
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
            child: Semantics(
              button: true,
              label: '編輯$name',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onEdit,
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
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Semantics(
            label: '$name完成',
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
