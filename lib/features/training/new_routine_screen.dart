import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_picker_screen.dart';
import 'set_load_table.dart';

/// A 課表 about to be kept, from a finished workout or a workout written
/// out: its name, its exercises and each one's sets, all to look over and
/// change before 儲存. Nothing is kept until then; back leaves it unmade.
///
/// Pops with true once kept.
class NewRoutineScreen extends StatefulWidget {
  const NewRoutineScreen({super.key, required this.planned});

  final List<PlannedExercise> planned;

  @override
  State<NewRoutineScreen> createState() => _NewRoutineScreenState();
}

class _NewRoutineScreenState extends State<NewRoutineScreen> {
  /// Each exercise as planned so far, keyed so a card keeps its fields
  /// when one above it is taken out.
  late final List<(Key, PlannedExercise)> _exercises = [
    for (final planned in widget.planned) (UniqueKey(), planned),
  ];

  late final _name = TextEditingController(
    text: AppStoreScope.read(context).routineNameOf(widget.planned),
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _setLoads(int index, List<SetLoad> loads) => setState(() {
    final (key, planned) = _exercises[index];
    _exercises[index] = (key, PlannedExercise.ofLoads(planned, loads));
  });

  void _remove(int index) => setState(() => _exercises.removeAt(index));

  Future<void> _add() async {
    final picked = await pushModalPage<List<ExerciseDefinition>>(
      context,
      ExercisePickerScreen(
        targetName: _name.text.trim(),
        purpose: PickerPurpose.template,
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final store = AppStoreScope.read(context);
    setState(
      () => _exercises.addAll([
        for (final exercise in picked) (UniqueKey(), store.usualPlan(exercise)),
      ]),
    );
  }

  void _save() {
    final routine = AppStoreScope.read(context).createRoutineOf([
      for (final (_, planned) in _exercises) planned,
    ], name: _name.text.trim());
    final toast = ToastScope.read(context);
    Navigator.of(context).pop(true);
    toast.show('已存成課表「${routine.name}」');
  }

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: const PageAppBar(title: '存成課表'),
      footer: PrimaryButton(
        label: '儲存',
        onPressed: _exercises.isEmpty || _name.text.trim().isEmpty
            ? null
            : _save,
      ),
      children: [
        Gutter(child: const SectionLabel('名稱')),
        Gutter(
          child: AppTextField(controller: _name, hint: '課表名稱'),
        ),
        Gutter(child: const SectionLabel('動作')),
        for (final (index, (key, planned)) in _exercises.indexed)
          Gutter(
            key: key,
            child: ExerciseLoadsCard(
              name: planned.exercise.name,
              loads: planned.loads,
              onLoads: (loads) => _setLoads(index, loads),
              onRemove: () => _remove(index),
            ),
          ),
        Gutter(
          child: DashedActionCard(label: '加入動作', onTap: _add),
        ),
      ],
    );
  }
}
