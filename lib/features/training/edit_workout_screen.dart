import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_picker_screen.dart';
import 'set_load_table.dart';

/// The longest a workout typed in may take, as a logged activity.
const _maxMinutes = 600;

/// A finished workout corrected after the fact: when it started and how
/// long it took, each exercise's sets at the weight and reps they were
/// really done at, an exercise taken out or one added. Nothing is
/// written until 儲存.
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
                if (set.isDone) (weightKg: set.weightKg, reps: set.reps),
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

  void _remove(int index) => setState(() {
    _exercises.removeAt(index);
    _isChanged = true;
  });

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
            (exercise: exercise, was: null, loads: store.usualLoads(exercise)),
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
    return DetailPage(
      appBar: PageAppBar(title: '編輯訓練', subtitle: widget.workout.routineName),
      // A workout with nothing left in it is deleted, not saved empty.
      footer: PrimaryButton(
        label: '儲存',
        onPressed:
            (_isChanged || _isRetimed) &&
                _exercises.isNotEmpty &&
                (!_isRetimed || _typedMinutes != null)
            ? _save
            : null,
      ),
      children: [
        PageSection(
          label: '時間',
          children: [
            Gutter(
              child: GroupedCard(
                children: [
                  NavRow(
                    title: '開始時間',
                    subtitle:
                        '${_startedAt.month} 月 ${_startedAt.day} 日 '
                        '${formatTimeOfDay(_startedAt)}',
                    onTap: _pickStart,
                  ),
                ],
              ),
            ),
            Gutter(
              child: NumberFieldRow(
                label: '時長',
                unit: '分鐘',
                controller: _minutes,
              ),
            ),
          ],
        ),
        Gutter(child: const SectionLabel('動作')),
        for (final (index, (key, correction)) in _exercises.indexed)
          Gutter(
            key: key,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          correction.exercise.name,
                          style: AppTextStyles.itemTitle,
                        ),
                      ),
                      ChipButton(
                        label: '移除',
                        semanticLabel: '移除「${correction.exercise.name}」',
                        onTap: () => _remove(index),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SetLoadTable(
                    loads: correction.loads,
                    onLoads: (loads) => _setLoads(index, loads),
                  ),
                ],
              ),
            ),
          ),
        Gutter(
          child: DashedActionCard(label: '加入動作', onTap: _add),
        ),
      ],
    );
  }
}
