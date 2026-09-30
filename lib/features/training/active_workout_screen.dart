import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/set_timer.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/haptics.dart';
import '../../shared/motion.dart';
import '../../shared/screen_awake.dart';
import '../../shared/widgets/content/elapsed_clock.dart';
import '../../backend/engines/training_metrics.dart';
import '../../backend/engines/workout_review.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_picker_screen.dart';
import '../shell/finish_session_dialog.dart';
import 'substitute_exercise_screen.dart';
import 'exercise_history_sheet.dart';
import 'set_editor_dialog.dart';
import 'set_names.dart';
import 'set_scheme_sheet.dart';
import 'workout_clock_dialogs.dart';
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

  /// Drops a workout that was arranged but never begun.
  Future<void> _cancelSchedule(BuildContext context) async {
    final store = AppStoreScope.read(context);
    final l10n = context.l10n;
    final isCancelled = await showAppDialog<bool>(
      context,
      AppDialog(
        title: l10n.cancelWorkoutTitle,
        actions: [
          DialogAction(
            label: l10n.cancelWorkoutAction,
            tone: DialogTone.destructive,
            onTap: () => Navigator.of(context).pop(true),
          ),
          DialogAction(
            label: l10n.keepWorkout,
            onTap: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
    if (isCancelled != true || !context.mounted) return;
    store.discardWorkout();
    Navigator.of(context).maybePop();
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
              largeHeight: _WorkoutHero.measureHeight(
                context,
                extraLines:
                    _heroTotals(context.l10n, workout, review).others.isEmpty
                    ? 0
                    : 1,
              ),
              isHighContrast: media.highContrast,
              reduceMotion: prefersReducedMotion(context),
              leading: const AppBarBackButton(),
              actions: [
                // Ready, the workout is only arranged: it can be dropped,
                // and there is nothing to pause or end yet.
                if (workout.isReady)
                  HeaderAction(
                    icon: Icons.close_rounded,
                    label: context.l10n.cancelSchedule,
                    semanticLabel: context.l10n.cancelWorkoutAction,
                    onTap: () => _cancelSchedule(context),
                  )
                else ...[
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

void _sayRecord(BuildContext context, WorkoutSet set, TrackingType type) =>
    showToast(
      context,
      context.l10n.personalRecordSet(set: set.figuresIn(context.l10n, type)),
      kind: ToastKind.success,
    );

/// What an exercise has come to so far, by how it is recorded: the volume
/// in kg for weight and reps, the total of its time, reps or distance for
/// the others; null while there is nothing to total.
String _totalOf(AppLocalizations l10n, ExerciseSession exercise) {
  return switch (exercise.exercise.trackingType) {
    TrackingType.weightReps => l10n.volumeValue(
      volume: formatKcal(sessionVolumeKg(exercise).round()),
    ),
    TrackingType.reps => '${l10n.totalReps} ${sessionReps(exercise)}',
    TrackingType.duration || TrackingType.weightDuration =>
      '${l10n.totalTime} ${formatClock(Duration(seconds: sessionSeconds(exercise)))}',
    TrackingType.distance =>
      '${l10n.totalDistance} ${formatKilometers(sessionMeters(exercise))} km',
  };
}

typedef _Total = ({String label, String value, bool hasValue});

/// The totals a workout shows in its header: the one it leads with, and
/// the others that have a value. Weight and reps lead as a volume in kg;
/// a workout with none of that leads with what its exercises are recorded
/// by, so it never reads `0 kg`.
({_Total lead, List<_Total> others}) _heroTotals(
  AppLocalizations l10n,
  WorkoutSession workout,
  WorkoutReview review,
) {
  final types = {for (final e in workout.exercises) e.exercise.trackingType};
  final totals = <_Total>[
    if (types.contains(TrackingType.weightReps))
      (
        label: l10n.totalVolume,
        value: '${formatKcal(review.volumeKg.round())} kg',
        hasValue: review.volumeKg > 0,
      ),
    if (types.contains(TrackingType.duration) ||
        types.contains(TrackingType.weightDuration))
      (
        label: l10n.totalTime,
        value: formatClock(Duration(seconds: review.seconds)),
        hasValue: review.seconds > 0,
      ),
    if (types.contains(TrackingType.reps))
      (
        label: l10n.totalReps,
        value: '${review.reps}',
        hasValue: review.reps > 0,
      ),
    if (types.contains(TrackingType.distance))
      (
        label: l10n.totalDistance,
        value: '${formatKilometers(review.meters)} km',
        hasValue: review.meters > 0,
      ),
  ];
  return (
    lead: totals.first,
    others: [
      for (final total in totals.skip(1))
        if (total.hasValue) total,
    ],
  );
}

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

  /// [extraLines] is how many lines of the other totals it has under the
  /// first.
  static double measureHeight(BuildContext context, {int extraLines = 0}) {
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
            ) *
            (1 + extraLines) +
        _heroBottomPadding;
  }

  @override
  Widget build(BuildContext context) {
    final totals = _heroTotals(context.l10n, workout, review);
    final previous = review.previousVolumeKg;
    // The change is in volume, so only a workout led by one has it.
    final change =
        previous == null ||
            previous == 0 ||
            totals.lead.label != context.l10n.totalVolume
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
              totals.lead.value,
              maxLines: 1,
              style: _heroVolumeStyle,
            ),
          ),
          const SizedBox(height: _heroGap),
          Text(
            [
              if (workout.isReady)
                context.l10n.workoutScheduled
              else if (workout.isPaused)
                context.l10n.sessionPausedStatus,
              totals.lead.label,
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
          if (totals.others.isNotEmpty)
            Text(
              [
                for (final total in totals.others)
                  '${total.label} ${total.value}',
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

/// The seconds a running rest is moved by, each way.
const _restAdjustments = [-15, 15, 30];

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
    final restExercise = store.restExercise;
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
                Semantics(
                  button: true,
                  label: context.l10n.restTimeTitle,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: restExercise == null
                          ? null
                          : () => showRestTimeDialog(
                              context,
                              exercise: restExercise,
                            ),
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.restTitle,
                              style: AppTextStyles.caption,
                            ),
                            Text(
                              formatClock(remaining),
                              style: AppTextStyles.bigNumber.copyWith(
                                color: AppColors.training,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Wraps under the figure rather than overflow at large text.
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    children: [
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
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final seconds in _restAdjustments)
                  ChipButton(
                    label: changeLabel(
                      seconds,
                      (size) => context.l10n.durationSeconds(seconds: size),
                    ),
                    onTap: () => store.extendRest(Duration(seconds: seconds)),
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
/// colour, while it is paused. A tap opens the clock to pause or correct.
class _TimeSoFar extends StatelessWidget {
  const _TimeSoFar({required this.workout});

  final WorkoutSession workout;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: context.l10n.workoutTimeTitle,
    child: Material(
      color: AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.button),
        onTap: () => showWorkoutTimeDialog(context),
        child: Container(
          height: buttonHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          // Scaled down as one, so large text shrinks it rather than
          // spilling out of the bar.
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
        ),
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

  static const _setColumn = 48.0;
  static const _doneColumn = 48.0;
  static const _timerColumn = 44.0;

  /// A set of these is timed as it is done, from a button beside it.
  static bool _hasTimer(TrackingType type) =>
      type == TrackingType.duration || type == TrackingType.weightDuration;

  /// Acts on this exercise, after making it the one being done.
  static AppStore _focused(BuildContext context, int index) {
    final store = AppStoreScope.read(context);
    store.focusExercise(index);
    return store;
  }

  void _toggle(BuildContext context, int setIndex) {
    final store = _focused(context, index);
    final timed = exercise.sets[setIndex];
    // Ticking a set that is being timed logs the time it took.
    if (!timed.isDone && identical(store.setTimer?.set, timed)) {
      store.editSet(
        setIndex,
        weightKg: timed.weightKg,
        reps: timed.reps,
        rir: timed.rir,
        seconds: store.stopSetTimer(),
      );
    }
    store.toggleSet(setIndex);
    final set = exercise.sets[setIndex];
    if (!set.isDone) return;
    store.restAfterSet(index);
    if (store.isPersonalRecord(exercise.exercise, set)) {
      _sayRecord(context, set, exercise.exercise.trackingType);
    }
  }

  void _startTimer(BuildContext context, int setIndex) =>
      _focused(context, index).startSetTimer(exercise.sets[setIndex]);

  void _commit(
    BuildContext context,
    int setIndex, {
    double? weightKg,
    int? reps,
    int? seconds,
    double? meters,
  }) {
    final set = exercise.sets[setIndex];
    final weight = weightKg ?? set.weightKg;
    final count = reps ?? set.reps;
    if (weight == set.weightKg &&
        count == set.reps &&
        (seconds ?? set.durationSeconds) == set.durationSeconds &&
        (meters ?? set.distanceMeters) == set.distanceMeters) {
      return;
    }
    _focused(context, index).editSet(
      setIndex,
      weightKg: weight,
      reps: count,
      rir: set.rir,
      seconds: seconds,
      meters: meters,
    );
  }

  /// The whole set in the editor: reps in reserve, the plates to load,
  /// or taking it off.
  Future<void> _edit(
    BuildContext context,
    int setIndex,
    ExerciseHistoryEntry? reference,
  ) async {
    final set = exercise.sets[setIndex];
    final edit = await showSetEditor(
      context,
      title: setName(context.l10n, set, workingNumber(exercise.sets, setIndex)),
      set: set,
      trackingType: exercise.exercise.trackingType,
      equipment: exercise.exercise.equipment,
      reference: reference,
    );
    if (!context.mounted) return;
    final store = _focused(context, index);
    switch (edit) {
      case SetChanged(
        :final weightKg,
        :final reps,
        :final rir,
        :final seconds,
        :final meters,
      ):
        store.editSet(
          setIndex,
          weightKg: weightKg,
          reps: reps,
          rir: rir,
          seconds: seconds,
          meters: meters,
        );
      case SetRemoved():
        store.removeSet(setIndex);
      case null:
        break;
    }
  }

  /// How the working sets are spread, from a scheme.
  Future<void> _pickScheme(
    BuildContext context,
    ExerciseHistory history,
  ) async {
    final loads = await showSetSchemeSheet(
      context,
      exercise: exercise,
      history: history,
      now: AppStoreScope.read(context).now(),
    );
    if (loads == null || !context.mounted) return;
    _focused(context, index).applyScheme(index, loads);
  }

  /// The working sets as they were in an earlier session.
  Future<void> _loadSession(BuildContext context) async {
    final store = AppStoreScope.read(context);
    final loads = await showExerciseHistorySheet(
      context,
      exercise: exercise.exercise,
      sessions: store.sessionsOf(exercise.exercise),
      now: store.now(),
    );
    if (loads == null || !context.mounted) return;
    _focused(context, index).loadSession(index, loads);
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
    final history = store.exerciseHistory(exercise.exercise);
    final last = history.last;
    final reference = relativeLoadReference(
      exercise.exercise,
      history,
      store.activeWorkout!.startedAt,
    );
    final type = exercise.exercise.trackingType;
    final fields = _fieldsOf(type);
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
              _totalOf(context.l10n, exercise),
              if (last != null)
                context.l10n.lastSetShort(
                  date: context.dates.compactMonthDay(last.date),
                  set: last.figuresIn(context.l10n, type),
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
                onTap: () => _loadSession(context),
              ),
              ChipButton(
                label: context.l10n.quickFill,
                semanticLabel: context.l10n.quickFillLabel,
                onTap: () => _pickScheme(context, history),
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
              for (final field in fields)
                Expanded(
                  flex: fields.length == 1 ? 2 : 1,
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: field == fields.last ? 0 : AppSpacing.xs,
                    ),
                    child: Text(
                      field.headingIn(context.l10n),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption,
                    ),
                  ),
                ),
              if (_hasTimer(type)) const SizedBox(width: _timerColumn),
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
                fields: fields,
                hasTimer: _hasTimer(type),
                timer: identical(store.setTimer?.set, set)
                    ? store.setTimer
                    : null,
                reference: reference,
                ordinal: workingNumber(exercise.sets, setIndex),
                isNext: isCurrent && setIndex == exercise.nextSetIndex,
                setColumn: _setColumn,
                doneColumn: _doneColumn,
                onWeight: (kg) => _commit(context, setIndex, weightKg: kg),
                onReps: (reps) => _commit(context, setIndex, reps: reps),
                onSeconds: (seconds) =>
                    _commit(context, setIndex, seconds: seconds),
                onMeters: (meters) =>
                    _commit(context, setIndex, meters: meters),
                onStartTimer: () => _startTimer(context, setIndex),
                onToggleTimer: store.toggleSetTimerPause,
                onToggle: () => _toggle(context, setIndex),
                onEdit: () => _edit(context, setIndex, reference),
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

/// The height of a set's row, and the button that opens the set within it.
const _setRowHeight = 48.0;
const _setButtonSize = 44.0;

/// One set as a row of the table: its number or kind, the weight and
/// reps to type in place, and the tick that logs it.
class _SetRow extends StatelessWidget {
  const _SetRow({
    super.key,
    required this.set,
    required this.fields,
    required this.hasTimer,
    required this.timer,
    required this.reference,
    required this.ordinal,
    required this.isNext,
    required this.setColumn,
    required this.doneColumn,
    required this.onWeight,
    required this.onReps,
    required this.onSeconds,
    required this.onMeters,
    required this.onStartTimer,
    required this.onToggleTimer,
    required this.onToggle,
    required this.onEdit,
  });

  final WorkoutSet set;

  /// The figures the exercise records, left to right.
  final List<_Field> fields;

  /// Whether the set is timed from a button, and the timer if it is running.
  final bool hasTimer;
  final SetTimer? timer;
  final ExerciseHistoryEntry? reference;

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
  final ValueChanged<int> onSeconds;
  final ValueChanged<double> onMeters;
  final VoidCallback onStartTimer;
  final VoidCallback onToggleTimer;
  final VoidCallback onToggle;

  /// One of the set's figures, typed in place or, for a time, set in its
  /// dialog; a set being timed shows the time counting up instead.
  Widget _fieldFor(BuildContext context, _Field field, String name) {
    final l10n = context.l10n;
    switch (field) {
      case _Field.weight:
        return InlineNumberField(
          text: formatWeight(set.weightKg),
          label: l10n.setWeight(set: name),
          decimal: true,
          onCommit: (text) {
            if (double.tryParse(text) case final kg? when kg >= 0) {
              onWeight(kg);
            }
          },
        );
      case _Field.reps:
        return InlineNumberField(
          text: '${set.reps}',
          label: l10n.setReps(set: name),
          decimal: false,
          onCommit: (text) {
            if (int.tryParse(text) case final reps? when reps >= 0) {
              onReps(reps);
            }
          },
        );
      case _Field.time:
        if (timer case final timer?) {
          return InlineValueButton(
            label: l10n.setTime(set: name),
            onTap: onToggleTimer,
            child: _TimingClock(timer: timer),
          );
        }
        return DurationField(
          seconds: set.durationSeconds ?? 0,
          label: l10n.setTime(set: name),
          onChanged: onSeconds,
        );
      case _Field.distance:
        return InlineNumberField(
          text: formatKilometers(set.distanceMeters ?? 0),
          label: l10n.setDistance(set: name),
          decimal: true,
          onCommit: (text) {
            if (double.tryParse(text) case final km? when km >= 0) {
              onMeters(km * 1000);
            }
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = setName(context.l10n, set, ordinal);
    final percent = relativeLoadPercent(set.weightKg, reference);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: setColumn,
              height: _setRowHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  button: true,
                  label: context.l10n.editItem(item: name),
                  // Excluding the child's semantics drops its tap too.
                  onTap: onEdit,
                  excludeSemantics: true,
                  child: Material(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      onTap: onEdit,
                      child: SizedBox.square(
                        dimension: _setButtonSize,
                        // Scaled down as one, so large text shrinks the
                        // number rather than spilling out of the button.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            ordinal == null
                                ? set.type
                                      .labelIn(context.l10n)
                                      .characters
                                      .first
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
                ),
              ),
            ),
            for (final field in fields)
              Expanded(
                flex: fields.length == 1 ? 2 : 1,
                child: Padding(
                  padding: EdgeInsets.only(
                    right: field == fields.last ? 0 : AppSpacing.xs,
                  ),
                  child: _fieldFor(context, field, name),
                ),
              ),
            if (hasTimer)
              SizedBox(
                width: _ExerciseCard._timerColumn,
                child: set.isDone
                    ? null
                    : SquareIconButton(
                        icon: timer == null || timer!.isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        tooltip: timer == null
                            ? context.l10n.setTimerStartLabel
                            : timer!.isPaused
                            ? context.l10n.commonResume
                            : context.l10n.commonPause,
                        size: _ExerciseCard._timerColumn,
                        onPressed: timer == null ? onStartTimer : onToggleTimer,
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
        ),
        if (percent case final percent?)
          Padding(
            padding: EdgeInsets.only(left: setColumn),
            child: Text(
              context.l10n.relativeLoadPercent(percent: percent.round()),
              style: AppTextStyles.caption,
            ),
          ),
      ],
    );
  }
}

/// A figure of a set, one column of the table.
enum _Field {
  weight,
  reps,
  time,
  distance;

  String headingIn(AppLocalizations l10n) => switch (this) {
    weight => 'kg',
    reps => l10n.repsColumn,
    time => l10n.timeColumn,
    distance => 'km',
  };
}

/// The figures an exercise records, left to right.
List<_Field> _fieldsOf(TrackingType type) => switch (type) {
  TrackingType.weightReps => const [_Field.weight, _Field.reps],
  TrackingType.reps => const [_Field.reps],
  TrackingType.duration => const [_Field.time],
  TrackingType.weightDuration => const [_Field.weight, _Field.time],
  TrackingType.distance => const [_Field.distance, _Field.time],
};

/// The time a set being timed has counted, ticking; the vibration when it
/// reaches what was planned comes from here, and the timer runs on.
class _TimingClock extends StatefulWidget {
  const _TimingClock({required this.timer});

  final SetTimer timer;

  @override
  State<_TimingClock> createState() => _TimingClockState();
}

class _TimingClockState extends State<_TimingClock> {
  late final Timer _tick = Timer.periodic(
    const Duration(seconds: 1),
    (_) => _onTick(),
  );

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  void _onTick() {
    if (AppStoreScope.read(context).settleSetTimer()) AppHaptics.alert();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = widget.timer.elapsedAt(AppStoreScope.read(context).now());
    return Text(
      formatClock(elapsed),
      style: TextStyle(
        color: widget.timer.isPaused ? AppColors.warning : AppColors.training,
      ),
    );
  }
}
