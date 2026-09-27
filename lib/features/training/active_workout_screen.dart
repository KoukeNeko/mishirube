import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/haptics.dart';
import '../../shared/motion.dart';
import '../../shared/screen_awake.dart';
import '../../shared/widgets/content/elapsed_clock.dart';
import '../../backend/engines/workout_review.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_picker_screen.dart';
import '../shell/finish_session_dialog.dart';
import 'substitute_exercise_screen.dart';
import 'set_editor_dialog.dart';
import 'workout_summary_screen.dart';
import '../../l10n/l10n.dart';

/// A workout under way: every exercise on one page, each a table of its
/// sets where weight and reps are typed in place and a tick logs the set
/// and starts the rest. The rest and the time so far sit at the foot with
/// the way to finish.
class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  /// One per exercise card, for bringing the one being done into view.
  final _cardKeys = <GlobalKey>[];

  @override
  void initState() {
    super.initState();
    // Opened mid-workout, the page starts at the exercise under way.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final workout = AppStoreScope.read(context).activeWorkout;
      if (workout == null || workout.currentExerciseIndex == 0) return;
      final key = workout.currentExerciseIndex < _cardKeys.length
          ? _cardKeys[workout.currentExerciseIndex]
          : null;
      if (key?.currentContext case final card?) {
        Scrollable.ensureVisible(card, alignment: 0.1);
      }
    });
  }

  void _finish(BuildContext context) {
    final store = AppStoreScope.read(context)..finishWorkout();
    replaceWithPage(
      context,
      WorkoutSummaryScreen(workoutId: store.lastFinishedWorkout?.id),
    );
  }

  /// Ends the workout. With every set done it simply finishes; with sets
  /// left it asks first.
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
        showToast(context, context.l10n.workoutDiscarded);
    }
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
    while (_cardKeys.length < workout.exercises.length) {
      _cardKeys.add(GlobalKey());
    }
    final review = store.workoutReview(workout);
    final media = MediaQuery.of(context);
    // Between sets the device sits on a bench; it should not lock.
    return ScreenAwake(
      child: EdgeToEdgeScaffold(
        // Measured below the Scaffold so text uses Material's line height.
        body: Builder(
          builder: (context) => CollapsingScrollView(
            header: CollapsingHeaderDelegate(
              toolbar: ToolbarMetrics.of(context),
              topInset: media.padding.top,
              largeHeight: _WorkoutHero.measureHeight(context),
              isHighContrast: media.highContrast,
              reduceMotion: prefersReducedMotion(context),
              leading: const AppBarBackButton(),
              actions: [
                // Nothing to pause before the time has started.
                if (!workout.isReady)
                  HeaderAction(
                    icon: workout.isPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    label: workout.isPaused
                        ? context.l10n.commonResume
                        : context.l10n.commonPause,
                    semanticLabel: workout.isPaused
                        ? context.l10n.sessionResume(
                            session: workout.routineName,
                          )
                        : context.l10n.sessionPause(
                            session: workout.routineName,
                          ),
                    onTap: store.togglePause,
                  ),
                HeaderAction(
                  icon: Icons.stop_rounded,
                  label: context.l10n.commonEnd,
                  semanticLabel: context.l10n.endWorkout,
                  onTap: () => _end(context, workout),
                ),
              ],
              compactTitle: _LiveTitle(workout: workout),
              large: _WorkoutHero(workout: workout, review: review),
            ),
            children: [
              for (final (index, exercise) in workout.exercises.indexed)
                Gutter(
                  key: _cardKeys[index],
                  child: _ExerciseCard(
                    index: index,
                    exercise: exercise,
                    isCurrent: index == workout.currentExerciseIndex,
                    isInSuperset: workout.supersetOf(index).length > 1,
                    canRemove: workout.exercises.length > 1,
                  ),
                ),
              Gutter(
                child: DashedActionCard(
                  label: context.l10n.addExercise,
                  onTap: () => _addExercises(context),
                ),
              ),
              Gutter(
                child: NavCard(
                  title: context.l10n.notesSection,
                  subtitle: switch (workout.notes) {
                    final notes? when notes.isNotEmpty => notes,
                    _ => context.l10n.notFilled,
                  },
                  onTap: () => _editNotes(context),
                ),
              ),
            ],
          ),
        ),
        // Ready, the page is for looking the plan over: the time starts
        // with 開始運動 (or the first set ticked).
        footer: BottomActionBar(
          child: workout.isReady
              ? PrimaryButton(
                  label: context.l10n.startExercising,
                  icon: Icons.play_arrow_outlined,
                  onPressed: store.beginWorkout,
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: AppSpacing.sm,
                  children: [
                    if (store.restEndsAt != null) const _RestTimer(),
                    Row(
                      spacing: AppSpacing.sm,
                      children: [
                        _TimeSoFar(workout: workout),
                        Expanded(
                          child: PrimaryButton(
                            label: context.l10n.finishWorkout,
                            onPressed: () => _end(context, workout),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

void _sayRecord(BuildContext context, WorkoutSet set) => showToast(
  context,
  context.l10n.personalRecordSet(
    set: '${formatWeight(set.weightKg)} kg × ${set.reps}',
  ),
  kind: ToastKind.success,
);

/// A working set's number among the working sets, since warm-ups come
/// first; null for any other kind of set.
int? _ordinal(List<WorkoutSet> sets, int index) {
  if (sets[index].type != SetType.working) return null;
  return sets
      .take(index + 1)
      .where((item) => item.type == SetType.working)
      .length;
}

/// `第 2 組`, or the kind of set it is: `熱身組`.
String _setName(AppLocalizations l10n, WorkoutSet set, int? ordinal) =>
    ordinal == null ? set.type.labelIn(l10n) : l10n.setOrdinal(number: ordinal);

/// Weight times reps over the done sets that count toward the work: not
/// the warm-ups.
double _volumeOf(ExerciseSession exercise) => exercise.sets
    .where((set) => set.isDone && set.type != SetType.warmup)
    .fold(0.0, (sum, set) => sum + set.weightKg * set.reps);

const _heroVolumeStyle = TextStyle(
  fontSize: 44,
  fontWeight: FontWeight.w800,
  color: AppColors.training,
  letterSpacing: -1,
  fontFeatures: [FontFeature.tabularFigures()],
);
const _heroGap = AppSpacing.xxs;
const _heroBottomPadding = AppSpacing.lg;

/// Branded live content at the top of the workout: how much has been
/// lifted, against last time. It scrolls away into [_LiveTitle].
class _WorkoutHero extends StatelessWidget {
  const _WorkoutHero({required this.workout, required this.review});

  final WorkoutSession workout;
  final WorkoutReview review;

  static double measureHeight(BuildContext context) {
    const maxWidth = double.infinity;
    return measureTextHeight(
          context,
          '0',
          _heroVolumeStyle,
          maxWidth: maxWidth,
        ) +
        _heroGap +
        measureTextHeight(
          context,
          context.l10n.totalShort,
          AppTextStyles.caption,
          maxWidth: maxWidth,
        ) +
        _heroBottomPadding;
  }

  @override
  Widget build(BuildContext context) {
    final previous = review.previousVolumeKg;
    final change = previous == null || previous == 0
        ? null
        : review.volumeKg - previous;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        0,
        AppSpacing.screenGutter,
        _heroBottomPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${formatKcal(review.volumeKg.round())} kg',
              maxLines: 1,
              style: _heroVolumeStyle,
            ),
          ),
          const SizedBox(height: _heroGap),
          Text(
            [
              if (workout.isReady)
                context.l10n.notStarted
              else if (workout.isPaused)
                context.l10n.sessionPausedStatus,
              context.l10n.totalVolume,
              if (change case final change?)
                context.l10n.versusLastTime(
                  change:
                      '${change < 0 ? '−' : '+'}${formatKcal(change.abs().round())} kg',
                ),
              context.l10n.setsOfTotal(
                done: workout.completedSets,
                total: workout.totalSets,
              ),
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption,
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
    return Text(
      workout.routineName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: compactTitleStyle,
    );
  }
}

/// The rest after a set, over the foot while it runs: what is left of
/// it, as a figure and a bar, and more time or an end to it at a tap.
class _RestTimer extends StatefulWidget {
  const _RestTimer();

  @override
  State<_RestTimer> createState() => _RestTimerState();
}

class _RestTimerState extends State<_RestTimer> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _timer.cancel();
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
    final left = endsAt.difference(store.now());
    final remaining = left.isNegative ? Duration.zero : left;
    final length = store.restLength.inMilliseconds;
    // Glass like the dock's: it floats over the page as the dock does.
    return ChromeSurface(
      refracts: true,
      radius: AppRadius.card,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.restTitle, style: AppTextStyles.caption),
                    Text(
                      formatClock(remaining),
                      style: AppTextStyles.bigNumber.copyWith(
                        color: AppColors.training,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      ChipButton(
                        label: context.l10n.rest30More,
                        onTap: () =>
                            store.extendRest(const Duration(seconds: 30)),
                      ),
                      ChipButton(
                        label: context.l10n.skipRest,
                        tone: TagTone.training,
                        onTap: store.skipRest,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ProgressLine(
              progress: length == 0 ? 0 : remaining.inMilliseconds / length,
            ),
          ],
        ),
      ),
    );
  }
}

/// The workout's time so far, beside 完成訓練; held still, in the warning
/// colour, while it is paused.
class _TimeSoFar extends StatelessWidget {
  const _TimeSoFar({required this.workout});

  final WorkoutSession workout;

  @override
  Widget build(BuildContext context) => Container(
    height: buttonHeight,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(AppRadius.button),
    ),
    // Scaled down as one, so large text shrinks it rather than spilling
    // out of the bar.
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElapsedClock(
            session: ActiveWorkout(workout),
            builder: (_, elapsed) => Text(
              elapsed,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: workout.isPaused
                    ? AppColors.warning
                    : AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            context.l10n.elapsedTime,
            style: AppTextStyles.caption.copyWith(fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

/// Asks for a note on the workout; it is kept with the record, not with
/// the template.
Future<void> _editNotes(BuildContext context) async {
  final store = AppStoreScope.read(context);
  final notes = await showTextDialog(
    context,
    title: context.l10n.workoutNotesTitle,
    initial: store.activeWorkout?.notes ?? '',
    hint: context.l10n.workoutNotesHint,
    maxLines: 3,
  );
  if (notes == null || !context.mounted) return;
  store.setWorkoutNotes(notes.trim());
}

/// What the card's menu does.
enum _ExerciseAction {
  warmup,
  drop,
  failure,
  replace,
  remove;

  String labelIn(AppLocalizations l10n) => switch (this) {
    warmup => l10n.addWarmupSets,
    drop => l10n.addDropSet,
    failure => l10n.addFailureSet,
    replace => l10n.replaceExercise,
    remove => l10n.removeFromWorkout,
  };
}

/// One exercise of the workout: its sets as a table to fill in and tick
/// off, what it has come to so far, and what it was last time.
class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.index,
    required this.exercise,
    required this.isCurrent,
    required this.isInSuperset,
    required this.canRemove,
  });

  final int index;
  final ExerciseSession exercise;

  /// The one being done: its next set is the one to do.
  final bool isCurrent;
  final bool isInSuperset;
  final bool canRemove;

  static const _setColumn = 40.0;
  static const _doneColumn = 48.0;

  /// Acts on this exercise, after making it the one being done.
  static AppStore _focused(BuildContext context, int index) {
    final store = AppStoreScope.read(context);
    store.focusExercise(index);
    return store;
  }

  void _toggle(BuildContext context, int setIndex) {
    final store = _focused(context, index);
    final workout = store.activeWorkout!;
    store.toggleSet(setIndex);
    final set = exercise.sets[setIndex];
    if (!set.isDone) return;
    if (workout.restsAfter(index)) store.startRest(exercise.exercise);
    if (store.isPersonalRecord(exercise.exercise, set)) {
      _sayRecord(context, set);
    }
  }

  void _commit(
    BuildContext context,
    int setIndex, {
    double? weightKg,
    int? reps,
  }) {
    final set = exercise.sets[setIndex];
    final weight = weightKg ?? set.weightKg;
    final count = reps ?? set.reps;
    if (weight == set.weightKg && count == set.reps) return;
    _focused(
      context,
      index,
    ).editSet(setIndex, weightKg: weight, reps: count, rir: set.rir);
  }

  /// The whole set in the editor: reps in reserve, the plates to load,
  /// or taking it off.
  Future<void> _edit(BuildContext context, int setIndex) async {
    final set = exercise.sets[setIndex];
    final edit = await showSetEditor(
      context,
      title: _setName(context.l10n, set, _ordinal(exercise.sets, setIndex)),
      set: set,
      equipment: exercise.exercise.equipment,
    );
    if (!context.mounted) return;
    final store = _focused(context, index);
    switch (edit) {
      case SetChanged(:final weightKg, :final reps, :final rir):
        store.editSet(setIndex, weightKg: weightKg, reps: reps, rir: rir);
      case SetRemoved():
        store.removeSet(setIndex);
      case null:
        break;
    }
  }

  Future<void> _menu(BuildContext context) async {
    final action = await showAppDialog<_ExerciseAction>(
      context,
      AppDialog(
        title: exercise.exercise.name,
        isChoiceList: true,
        actions: [
          for (final action in _ExerciseAction.values)
            if (action != _ExerciseAction.remove || canRemove)
              DialogAction(
                label: action.labelIn(context.l10n),
                tone: action == _ExerciseAction.remove
                    ? DialogTone.destructive
                    : DialogTone.normal,
                onTap: () => Navigator.of(context).pop(action),
              ),
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    final store = _focused(context, index);
    switch (action) {
      case _ExerciseAction.warmup:
        store.addWarmups();
      case _ExerciseAction.drop:
        store.addSet(SetType.drop);
      case _ExerciseAction.failure:
        store.addSet(SetType.failure);
      case _ExerciseAction.replace:
        pushPage(context, const SubstituteExerciseScreen());
      case _ExerciseAction.remove:
        store.removeExercise(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final last = store.exerciseHistory(exercise.exercise).last;
    final volume = _volumeOf(exercise);
    return AppCard(
      borderColor: isCurrent ? AppColors.training : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${index + 1} ',
                style: AppTextStyles.itemTitle.copyWith(
                  color: AppColors.training,
                ),
              ),
              Expanded(
                child: Text(
                  exercise.exercise.name,
                  style: AppTextStyles.itemTitle,
                ),
              ),
              if (isInSuperset)
                TagChip(label: context.l10n.superset, tone: TagTone.training),
              SquareIconButton(
                icon: Icons.more_horiz,
                tooltip: context.l10n.optionsFor(name: exercise.exercise.name),
                onPressed: () => _menu(context),
              ),
            ],
          ),
          Text(
            [
              context.l10n.volumeValue(volume: formatKcal(volume.round())),
              if (last != null)
                context.l10n.lastSetShort(
                  date: context.dates.compactMonthDay(last.date),
                  set: '${formatWeight(last.weightKg)} kg × ${last.reps}',
                ),
            ].join(' · '),
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              ChipButton(
                label: context.l10n.loadPrevious,
                semanticLabel: context.l10n.loadPreviousLabel,
                onTap: () => _focused(context, index).loadPrevious(index),
              ),
              ChipButton(
                label: context.l10n.quickFill,
                semanticLabel: context.l10n.quickFillLabel,
                onTap: () => _focused(context, index).fillFromFirst(index),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              SizedBox(
                width: _setColumn,
                child: Text(
                  context.l10n.setColumn,
                  style: AppTextStyles.caption,
                ),
              ),
              const Expanded(
                child: Text(
                  'kg',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  context.l10n.repsColumn,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              SizedBox(
                width: _doneColumn,
                child: Text(
                  context.l10n.commonDone,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ),
          for (final (setIndex, set) in exercise.sets.indexed)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: _SetRow(
                // A set's cells keep their own text while typed in; a
                // key per set keeps them with it when one is removed.
                key: ObjectKey(set),
                set: set,
                ordinal: _ordinal(exercise.sets, setIndex),
                isNext: isCurrent && setIndex == exercise.nextSetIndex,
                setColumn: _setColumn,
                doneColumn: _doneColumn,
                onWeight: (kg) => _commit(context, setIndex, weightKg: kg),
                onReps: (reps) => _commit(context, setIndex, reps: reps),
                onToggle: () => _toggle(context, setIndex),
                onEdit: () => _edit(context, setIndex),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            spacing: AppSpacing.sm,
            children: [
              Expanded(
                child: SecondaryButton(
                  label: context.l10n.removeSet,
                  icon: Icons.remove,
                  isCompact: true,
                  onPressed: exercise.sets.isEmpty
                      ? null
                      : () => _focused(context, index).removeLastSet(index),
                ),
              ),
              Expanded(
                child: SecondaryButton(
                  label: context.l10n.addSet,
                  icon: Icons.add,
                  isCompact: true,
                  onPressed: () =>
                      _focused(context, index).addSet(SetType.working),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One set as a row of the table: its number or kind, the weight and
/// reps to type in place, and the tick that logs it.
class _SetRow extends StatelessWidget {
  const _SetRow({
    super.key,
    required this.set,
    required this.ordinal,
    required this.isNext,
    required this.setColumn,
    required this.doneColumn,
    required this.onWeight,
    required this.onReps,
    required this.onToggle,
    required this.onEdit,
  });

  final WorkoutSet set;

  /// Opens the whole set: reps in reserve, plates, removing it.
  final VoidCallback onEdit;

  /// Its number among the working sets; null for a warm-up, drop or
  /// failure set, which is shown by its kind.
  final int? ordinal;

  /// The set to do next, marked so the eye finds it.
  final bool isNext;
  final double setColumn;
  final double doneColumn;
  final ValueChanged<double> onWeight;
  final ValueChanged<int> onReps;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final name = _setName(context.l10n, set, ordinal);
    return Row(
      children: [
        SizedBox(
          width: setColumn,
          height: 48,
          child: Semantics(
            button: true,
            label: context.l10n.editItem(item: name),
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onEdit,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  ordinal == null
                      ? set.type.labelIn(context.l10n).characters.first
                      : '$ordinal',
                  style: AppTextStyles.itemTitle.copyWith(
                    color: ordinal == null
                        ? AppColors.textSecondary
                        : isNext
                        ? AppColors.training
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: InlineNumberField(
            text: formatWeight(set.weightKg),
            label: context.l10n.setWeight(set: name),
            decimal: true,
            onCommit: (text) {
              if (double.tryParse(text) case final kg? when kg >= 0) {
                onWeight(kg);
              }
            },
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: InlineNumberField(
            text: '${set.reps}',
            label: context.l10n.setReps(set: name),
            decimal: false,
            onCommit: (text) {
              if (int.tryParse(text) case final reps? when reps >= 0) {
                onReps(reps);
              }
            },
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: doneColumn,
          child: Semantics(
            label: context.l10n.setDone(set: name),
            checked: set.isDone,
            child: GestureDetector(
              onTap: onToggle,
              child: Center(
                child: CheckSquare(
                  isChecked: set.isDone,
                  size: 44,
                  uncheckedColor: isNext
                      ? AppColors.trainingSurface
                      : AppColors.surfaceRaised,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
