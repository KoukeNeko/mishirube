import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/engines/training_metrics.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_picker_screen.dart';
import 'active_workout_screen.dart';
import 'progression_card.dart';
import 'set_load_table.dart';
import 'workout_summary_screen.dart';
import '../../l10n/l10n.dart';

/// A workout's plan (a template). Editing it never rewrites finished
/// workouts.
class RoutineDetailScreen extends StatefulWidget {
  const RoutineDetailScreen({super.key});

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  /// Muscles still sore today; each exercise working one gets a set
  /// fewer when the workout starts. Kept for the visit only.
  final _sore = <MuscleGroup>{};

  Future<void> _addExercises(BuildContext context, Routine routine) async {
    final store = AppStoreScope.read(context);
    final selected = await pushModalPage<List<ExerciseDefinition>>(
      context,
      ExercisePickerScreen(
        targetName: routine.name,
        purpose: PickerPurpose.template,
      ),
    );
    if (selected == null || selected.isEmpty) return;
    store.addExercises(selected);
  }

  /// Removing is undoable: the plan is restored as it was.
  void _remove(AppStore store, Routine routine, int index) {
    final removed = routine.exercises[index];
    store.removeRoutineExercise(index);
    ToastScope.read(context).showUndo(
      context.l10n.removedNamed(name: removed.exercise.name),
      onUndo: () => store.restoreRoutine(routine),
    );
  }

  Future<void> _rename(Routine routine) async {
    final name = await showTextDialog(
      context,
      title: context.l10n.routineName,
      initial: routine.name,
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    AppStoreScope.read(context).renameRoutine(name.trim());
  }

  /// Removing a template is undoable and never touches the workouts done
  /// from it. The page closes with it.
  Future<void> _delete(Routine routine) async {
    final store = AppStoreScope.read(context);
    final confirmed = await showAppDialog<bool>(
      context,
      AppDialog(
        title: context.l10n.deleteNamedTitle(name: routine.name),
        message: context.l10n.routineDeleteKeeps,
        actions: [
          DialogAction(
            label: context.l10n.deleteRoutine,
            tone: DialogTone.destructive,
            onTap: () => Navigator.of(context).pop(true),
          ),
          DialogAction(
            label: context.l10n.commonCancel,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final toast = ToastScope.read(context);
    Navigator.of(context).pop();
    store.deleteRoutine(routine);
    toast.showUndo(
      context.l10n.deletedNamed(name: routine.name),
      onUndo: () => store.undeleteRoutine(routine.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    // Deleted from here, while the page leaves.
    final routine = store.selectedRoutine;
    if (routine == null) {
      return DetailPage(
        appBar: PageAppBar(title: context.l10n.moduleTraining),
        children: [],
      );
    }
    final isWorkoutActive = store.activeWorkout != null;
    return DetailPage(
      appBar: PageAppBar(
        title: routine.name,
        subtitle: context.l10n.aboutMinutesShort(
          minutes: store.expectedMinutes(routine),
        ),
      ),
      footer: PrimaryButton(
        label: isWorkoutActive
            ? context.l10n.backToWorkout
            : context.l10n.startWorkout,
        icon: Icons.play_arrow_outlined,
        onPressed: () {
          // Exercise being timed is the user's to end first.
          if (!store.startWorkout(sore: _sore)) {
            showToast(
              context,
              context.l10n.activityBlocksWorkout,
              kind: ToastKind.warning,
            );
            return;
          }
          openFromRoot(context, const ActiveWorkoutScreen());
        },
      ),
      children: [
        Gutter(child: SectionLabel(context.l10n.plannedExercises)),
        for (final (index, planned) in routine.exercises.indexed)
          Gutter(
            child: _PlannedExerciseCard(
              planned: planned,
              canMoveUp: index > 0,
              canMoveDown: index < routine.exercises.length - 1,
              onMove: (offset) =>
                  store.moveRoutineExercise(index, index + offset),
              onRemove: () => _remove(store, routine, index),
              isLighter:
                  worksSoreMuscle(planned, _sore) &&
                  setsWhenSore(planned.sets) < planned.sets,
              isInSuperset:
                  planned.joinsNext ||
                  (index > 0 && routine.exercises[index - 1].joinsNext),
              onJoinNext: (joins) => store.setJoinsNext(index, joins: joins),
              onLoads: (loads) => store.editLoads(index, loads),
              last: switch (store.exerciseHistory(planned.exercise).last) {
                final last? => (weightKg: last.weightKg, reps: last.reps),
                null => null,
              },
            ),
          ),
        Gutter(
          child: DashedActionCard(
            label: context.l10n.addExercise,
            onTap: () => _addExercises(context, routine),
          ),
        ),
        if (!isWorkoutActive) ...[
          Gutter(child: SectionLabel(context.l10n.soreMusclesToday)),
          Gutter(
            child: ChipWrap(
              options: {
                for (final planned in routine.exercises)
                  ...planned.exercise.primaryMuscles,
              }.toList(),
              labelOf: (muscle) => muscle.labelIn(context.l10n),
              isSelected: _sore.contains,
              onTap: (muscle) => setState(
                () => _sore.contains(muscle)
                    ? _sore.remove(muscle)
                    : _sore.add(muscle),
              ),
            ),
          ),
        ],
        ProgressionSection(routine: routine),
        if (store.recentRoutineWorkouts case final recent
            when recent.isNotEmpty) ...[
          Gutter(child: SectionLabel(context.l10n.recentlyDone)),
          for (final workout in recent)
            Gutter(
              child: AccentRow(
                color: AppColors.training,
                title: context.dates.dayWithWeekday(workout.startedAt),
                subtitle: context.l10n.setsAndMinutes(
                  sets: workout.completedSets,
                  minutes: workout.elapsedAt(workout.finishedAt!).inMinutes,
                ),
                showChevron: true,
                onTap: () => pushPage(
                  context,
                  WorkoutSummaryScreen(workoutId: workout.id),
                ),
              ),
            ),
        ],
        PageSection(
          label: context.l10n.manageSection,
          children: [
            Gutter(
              child: GroupedCard(
                children: [
                  NavRow(
                    title: context.l10n.rename,
                    onTap: () => _rename(routine),
                  ),
                  NavRow(
                    title: context.l10n.deleteRoutine,
                    isDestructive: true,
                    onTap: () => _delete(routine),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// What the edit controls on a planned exercise do.
enum _PlanEdit {
  up,
  down,
  join,
  leave,
  remove;

  String labelIn(AppLocalizations l10n) => switch (this) {
    up => l10n.moveUp,
    down => l10n.moveDown,
    join => l10n.joinSuperset,
    leave => l10n.leaveSuperset,
    remove => l10n.removeAction,
  };
}

class _PlannedExerciseCard extends StatelessWidget {
  const _PlannedExerciseCard({
    required this.planned,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMove,
    required this.onRemove,
    required this.isInSuperset,
    required this.onJoinNext,
    required this.isLighter,
    required this.onLoads,
    this.last,
  });

  /// A muscle it works is sore today: a set fewer when started.
  final bool isLighter;

  /// Plans the exercise as these sets; none takes it out.
  final ValueChanged<List<SetLoad>> onLoads;

  /// How it was last done, for filling the plan in from.
  final SetLoad? last;

  final PlannedExercise planned;
  final bool canMoveUp;
  final bool canMoveDown;

  /// Done in turn with the exercise before or after it.
  final bool isInSuperset;

  /// Joins the exercise with the next one, or leaves that superset.
  final ValueChanged<bool> onJoinNext;

  /// Moves the exercise by the given offset in the plan.
  final ValueChanged<int> onMove;
  final VoidCallback onRemove;

  Future<void> _menu(BuildContext context) async {
    final edit = await showAppDialog<_PlanEdit>(
      context,
      AppDialog(
        title: planned.exercise.name,
        isChoiceList: true,
        actions: [
          for (final edit in [
            if (canMoveUp) _PlanEdit.up,
            if (canMoveDown) _PlanEdit.down,
            if (canMoveDown)
              planned.joinsNext ? _PlanEdit.leave : _PlanEdit.join,
            _PlanEdit.remove,
          ])
            DialogAction(
              label: edit.labelIn(context.l10n),
              tone: edit == _PlanEdit.remove
                  ? DialogTone.destructive
                  : DialogTone.normal,
              onTap: () => Navigator.of(context).pop(edit),
            ),
        ],
      ),
    );
    switch (edit) {
      case _PlanEdit.up:
        onMove(-1);
      case _PlanEdit.down:
        onMove(1);
      case _PlanEdit.join:
        onJoinNext(true);
      case _PlanEdit.leave:
        onJoinNext(false);
      case _PlanEdit.remove:
        onRemove();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final qualifier = planned.isUnilateral
        ? context.l10n.eachSide
        : planned.rir == null
        ? null
        : 'RIR ${planned.rir}';
    final loads = planned.loads;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  planned.exercise.name,
                  style: AppTextStyles.itemTitle,
                ),
              ),
              if (qualifier != null)
                Text(qualifier, style: AppTextStyles.caption),
              SquareIconButton(
                icon: Icons.more_horiz,
                tooltip: context.l10n.optionsFor(name: planned.exercise.name),
                onPressed: () => _menu(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(
                Icons.trending_up,
                size: 16,
                color: AppColors.training,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  planned.progressionLabel,
                  style: const TextStyle(
                    color: AppColors.training,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isLighter) TagChip(label: context.l10n.oneSetLessToday),
              if (isInSuperset) ...[
                const SizedBox(width: AppSpacing.xs),
                TagChip(label: context.l10n.superset, tone: TagTone.training),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SetLoadTable(
            loads: loads,
            onLoads: onLoads,
            headerAction: last == null
                ? null
                : ChipButton(
                    label: context.l10n.loadPrevious,
                    semanticLabel: context.l10n.loadPreviousFill,
                    onTap: () => onLoads([for (final _ in loads) last!]),
                  ),
          ),
        ],
      ),
    );
  }
}
