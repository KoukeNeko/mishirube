import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../backend/engines/program_generator.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';
import '../trends/muscle_load_card.dart';

extension on ProgramPlace {
  String labelIn(AppLocalizations l10n) => switch (this) {
    ProgramPlace.gym => l10n.programEquipmentGym,
    ProgramPlace.dumbbells => l10n.equipmentDumbbell,
    ProgramPlace.bodyweight => l10n.equipmentBodyweight,
  };
}

/// Builds a set of 課表 from a few answers: the goal, the experience, the
/// days and minutes there are, and the equipment. The result shows as the
/// answers change, and nothing is kept until 儲存; each workout is then a
/// 課表 of its own, to be changed the way any other is.
///
/// Pops with true once kept.
class GenerateRoutinesScreen extends StatefulWidget {
  const GenerateRoutinesScreen({super.key});

  @override
  State<GenerateRoutinesScreen> createState() => _GenerateRoutinesScreenState();
}

class _GenerateRoutinesScreenState extends State<GenerateRoutinesScreen> {
  static const _days = [2, 3, 4, 5, 6];

  late ProgramRequest _request = AppStoreScope.read(context)
      .suggestedProgramRequest;
  late GeneratedProgram _program = AppStoreScope.read(context)
      .buildProgram(_request);

  /// Asks again after any change to the answers.
  void _change(ProgramRequest request) => setState(() {
    _request = request;
    _program = AppStoreScope.read(context).buildProgram(request);
  });

  void _save() {
    final saved = AppStoreScope.read(context).saveProgram(_program);
    final toast = ToastScope.read(context);
    Navigator.of(context).pop(true);
    toast.show(context.l10n.savedRoutinesCount(count: saved.length));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final weeklySets = _program.weeklySets;
    return DetailPage(
      appBar: PageAppBar(title: l10n.generateRoutines),
      footer: PrimaryButton(
        label: l10n.commonSave,
        onPressed: _program.workouts.isEmpty ? null : _save,
      ),
      children: [
        Gutter(child: SectionLabel(l10n.programGoal)),
        Gutter(
          child: SegmentedChoice<ProgramGoal>(
            options: ProgramGoal.values,
            selected: _request.goal,
            labelOf: (goal) => goal.labelIn(l10n),
            onChanged: (goal) => _change(_request.copyWith(goal: goal)),
          ),
        ),
        Gutter(child: SectionLabel(l10n.programLevel)),
        Gutter(
          child: SegmentedChoice<ProgramLevel>(
            options: ProgramLevel.values,
            selected: _request.level,
            labelOf: (level) => level.labelIn(l10n),
            onChanged: (level) => _change(_request.copyWith(level: level)),
          ),
        ),
        Gutter(child: SectionLabel(l10n.programDays)),
        Gutter(
          child: SegmentedChoice<int>(
            options: _days,
            selected: _request.days,
            labelOf: (days) => l10n.daysCount(count: days),
            onChanged: (days) => _change(_request.copyWith(days: days)),
          ),
        ),
        Gutter(child: SectionLabel(l10n.programMinutes)),
        Gutter(
          child: SegmentedChoice<int>(
            options: programMinutes,
            selected: _request.minutes,
            labelOf: (minutes) => l10n.durationMinutes(minutes: minutes),
            onChanged: (minutes) =>
                _change(_request.copyWith(minutes: minutes)),
          ),
        ),
        Gutter(child: SectionLabel(l10n.equipmentSection)),
        Gutter(
          child: SegmentedChoice<ProgramPlace>(
            options: ProgramPlace.values,
            selected: ProgramPlace.of(_request.equipment),
            labelOf: (place) => place.labelIn(l10n),
            onChanged: (place) =>
                _change(_request.copyWith(equipment: place.equipment)),
          ),
        ),
        Gutter(
          child: SecondaryButton(
            label: l10n.shuffleProgram,
            icon: Icons.shuffle,
            onPressed: () =>
                _change(_request.copyWith(variant: _request.variant + 1)),
          ),
        ),
        for (final workout in _program.workouts) ...[
          Gutter(
            child: SectionLabel(
              [
                _program.nameOf(l10n, workout),
                l10n.routineSummary(
                  exercises: workout.exercises.length,
                  sets: workout.totalSets,
                ),
                l10n.durationMinutes(minutes: workout.length.inMinutes),
              ].join(' · '),
            ),
          ),
          Gutter(
            child: GroupedCard(
              children: [
                for (final planned in workout.exercises)
                  NavRow(
                    title: planned.exercise.name,
                    trailing: Text(
                      _plannedFigures(planned),
                      style: AppTextStyles.itemTitle,
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (weeklySets.isNotEmpty) ...[
          Gutter(child: SectionLabel(l10n.weeklySetsTitle)),
          Gutter(
            child: AppCard(child: MuscleSetBars(load: weeklySets)),
          ),
        ],
      ],
    );
  }
}

/// `3 × 8`, or `3 × 0:45` for an exercise held for a time.
String _plannedFigures(PlannedExercise planned) {
  final seconds = planned.targetSeconds;
  return seconds != null && planned.reps == 0
      ? '${planned.sets} × ${formatClock(Duration(seconds: seconds))}'
      : '${planned.sets} × ${planned.reps}';
}
