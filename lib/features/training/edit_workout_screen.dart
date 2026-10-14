import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_picker_screen.dart';
import 'set_load_table.dart';
import '../../l10n/l10n.dart';

/// The longest a workout typed in may take, as a logged activity.
const _maxMinutes = 600;

/// A finished workout corrected after the fact: when it started and how
/// long it took, each exercise's sets at the weight and reps they were
/// really done at, an exercise taken out, swapped for another or one
/// added. Nothing is written until 儲存.
class EditWorkoutScreen extends StatefulWidget {
  const EditWorkoutScreen({super.key, required this.workout});

  final WorkoutSession workout;

  @override
  State<EditWorkoutScreen> createState() => _EditWorkoutScreenState();
}

class _EditWorkoutScreenState extends State<EditWorkoutScreen> {
  /// Each exercise as it is being corrected, keyed so a card keeps its
  /// fields when one above it is taken out.
  late final List<(Key, WorkoutCorrection)> _exercises = [
    for (final session in widget.workout.exercises)
      if (session.completedSets > 0)
        (
          UniqueKey(),
          (
            exercise: session.exercise,
            was: session,
            loads: [
              for (final set in session.sets)
                if (set.isDone)
                  SetLoad(
                    weightKg: set.weightKg,
                    reps: set.reps,
                    seconds: set.durationSeconds,
                    meters: set.distanceMeters,
                  ),
            ],
          ),
        ),
  ];

  bool _isChanged = false;

  late DateTime _startedAt = widget.workout.startedAt;

  /// Its length in whole minutes, as it was; the time is rewritten only
  /// when this or the start changes, so seconds and pauses are not lost
  /// by opening the page.
  late final _minutesWas =
      '${widget.workout.elapsedAt(widget.workout.finishedAt!).inMinutes}';
  late final _minutes = TextEditingController(text: _minutesWas)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  bool get _isRetimed =>
      _startedAt != widget.workout.startedAt || _minutes.text != _minutesWas;

  /// The length typed in, when it is one a workout can have.
  int? get _typedMinutes => switch (int.tryParse(_minutes.text.trim())) {
    final minutes? when minutes >= 1 && minutes <= _maxMinutes => minutes,
    _ => null,
  };

  Future<void> _pickStart() async {
    final picked = await pickDateTime(
      context,
      initial: _startedAt,
      latest: AppStoreScope.read(context).now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _startedAt = picked);
  }

  void _setLoads(int index, List<SetLoad> loads) => setState(() {
    final (key, correction) = _exercises[index];
    _exercises[index] = (
      key,
      (exercise: correction.exercise, was: correction.was, loads: loads),
    );
    _isChanged = true;
  });

  /// The exercise at [from] goes to [to], its place once it is out.
  void _move(int from, int to) => setState(() {
    _exercises.insert(to, _exercises.removeAt(from));
    _isChanged = true;
  });

  void _remove(int index) => setState(() {
    _exercises.removeAt(index);
    _isChanged = true;
  });

  /// Swaps the exercise at [index] for one from the library: the sets stay
  /// as they were done, unless the new one is recorded another way (reps
  /// for a time), when its usual sets take their place.
  Future<void> _replace(int index) async {
    final picked = await pushModalPage<List<ExerciseDefinition>>(
      context,
      const ExercisePickerScreen(purpose: PickerPurpose.single),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final replacement = picked.first;
    final (key, correction) = _exercises[index];
    if (replacement == correction.exercise) return;
    final store = AppStoreScope.read(context);
    setState(() {
      _exercises[index] = (
        key,
        (
          exercise: replacement,
          was: correction.was,
          loads: replacement.trackingType == correction.exercise.trackingType
              ? correction.loads
              : store.usualPlan(replacement).loads,
        ),
      );
      _isChanged = true;
    });
  }

  Future<void> _add() async {
    final picked = await pushModalPage<List<ExerciseDefinition>>(
      context,
      ExercisePickerScreen(
        targetName: widget.workout.routineName,
        purpose: PickerPurpose.record,
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final store = AppStoreScope.read(context);
    setState(() {
      _exercises.addAll([
        for (final exercise in picked)
          (
            UniqueKey(),
            (
              exercise: exercise,
              was: null,
              loads: store.usualPlan(exercise).loads,
            ),
          ),
      ]);
      _isChanged = true;
    });
  }

  void _save() {
    AppStoreScope.read(context).correctWorkout(
      widget.workout,
      [for (final (_, correction) in _exercises) correction],
      timing: _isRetimed
          ? (startedAt: _startedAt, length: Duration(minutes: _typedMinutes!))
          : null,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // What comes before the exercises, which are held by their headers and
    // dragged into another order.
    final before = [
      PageSection(
        label: context.l10n.timeSection,
        children: [
          Gutter(
            child: GroupedCard(
              children: [
                NavRow(
                  title: context.l10n.activityStartTime,
                  subtitle:
                      '${context.dates.monthDay(_startedAt)} '
                      '${formatTimeOfDay(_startedAt)}',
                  onTap: _pickStart,
                ),
              ],
            ),
          ),
          Gutter(
            child: NumberFieldRow(
              label: context.l10n.durationLabel,
              unit: context.l10n.minutesUnit,
              controller: _minutes,
            ),
          ),
        ],
      ),
      Gutter(child: SectionLabel(context.l10n.exercisesLabel)),
    ];
    return DetailPage(
      appBar: PageAppBar(
        title: context.l10n.editWorkout,
        subtitle: widget.workout.routineName,
      ),
      reorder: ReorderableChildren(
        start: before.length,
        count: _exercises.length,
        onReorder: _move,
      ),
      // A workout with nothing left in it is deleted, not saved empty.
      footer: PrimaryButton(
        label: context.l10n.commonSave,
        onPressed:
            (_isChanged || _isRetimed) &&
                _exercises.isNotEmpty &&
                (!_isRetimed || _typedMinutes != null)
            ? _save
            : null,
      ),
      children: [
        ...before,
        for (final (index, (key, correction)) in _exercises.indexed)
          Gutter(
            key: key,
            child: ExerciseLoadsCard(
              name: correction.exercise.name,
              trackingType: correction.exercise.trackingType,
              loads: correction.loads,
              onLoads: (loads) => _setLoads(index, loads),
              onRemove: () => _remove(index),
              onReplace: () => _replace(index),
              reorderIndex: index,
            ),
          ),
        Gutter(
          child: DashedActionCard(label: context.l10n.addExercise, onTap: _add),
        ),
      ],
    );
  }
}
