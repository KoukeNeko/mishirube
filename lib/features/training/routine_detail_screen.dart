import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/engines/training_metrics.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_picker_screen.dart';
import 'active_workout_screen.dart';
import 'progression_card.dart';
import 'set_load_table.dart';
import 'training_screen.dart';
import 'workout_summary_screen.dart';

/// A workout's plan (a template). Editing it never rewrites finished
/// workouts.
class RoutineDetailScreen extends StatefulWidget {
  const RoutineDetailScreen({super.key});

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  /// Editing shows the controls that change the plan's shape, so a tap
  /// while browsing cannot reorder or remove anything.
  bool _isEditing = false;

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
      '已移除「${removed.exercise.name}」',
      onUndo: () => store.restoreRoutine(routine),
    );
  }

  Future<void> _rename(Routine routine) async {
    final name = await showTextDialog(
      context,
      title: '課表名稱',
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
        title: '刪除「${routine.name}」？',
        message: '已完成的訓練紀錄會保留。',
        actions: [
          DialogAction(
            label: '刪除這份課表',
            tone: DialogTone.destructive,
            onTap: () => Navigator.of(context).pop(true),
          ),
          DialogAction(label: '取消', onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final toast = ToastScope.read(context);
    Navigator.of(context).pop();
    store.deleteRoutine(routine);
    toast.showUndo(
      '已刪除「${routine.name}」',
      onUndo: () => store.undeleteRoutine(routine.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    // Deleted from here, while the page leaves.
    final routine = store.selectedRoutine;
    if (routine == null) {
      return const DetailPage(
        appBar: PageAppBar(title: '訓練'),
        children: [],
      );
    }
    final isWorkoutActive = store.activeWorkout != null;
    return DetailPage(
      appBar: PageAppBar(
        title: routine.name,
        subtitle: '約 ${store.expectedMinutes(routine)} 分',
        actions: [
          HeaderAction(
            icon: Icons.list_alt_outlined,
            semanticLabel: '所有課表',
            onTap: () => pushPage(context, const TrainingScreen()),
          ),
          HeaderAction(
            icon: _isEditing ? Icons.check : Icons.edit_outlined,
            label: _isEditing ? '完成' : '編輯',
            semanticLabel: _isEditing ? '完成編輯' : '編輯這份課表',
            onTap: () => setState(() => _isEditing = !_isEditing),
          ),
        ],
      ),
      footer: PrimaryButton(
        label: isWorkoutActive ? '回到訓練' : '開始訓練',
        icon: Icons.play_arrow_outlined,
        onPressed: () {
          store.startWorkout(sore: _sore);
          replaceWithPage(context, const ActiveWorkoutScreen());
        },
      ),
      children: [
        if (!_isEditing && !isWorkoutActive) ...[
          Gutter(child: const SectionLabel('今天酸痛的肌群')),
          Gutter(
            child: ChipWrap(
              options: {
                for (final planned in routine.exercises)
                  ...planned.exercise.primaryMuscles,
              }.toList(),
              labelOf: (muscle) => muscle.label,
              isSelected: _sore.contains,
              onTap: (muscle) => setState(
                () => _sore.contains(muscle)
                    ? _sore.remove(muscle)
                    : _sore.add(muscle),
              ),
            ),
          ),
        ],
        Gutter(
          child: SectionLabel(
            '計畫的動作',
            trailing: _isEditing
                ? LinkText(label: '改名稱', onTap: () => _rename(routine))
                : null,
          ),
        ),
        for (final (index, planned) in routine.exercises.indexed)
          Gutter(
            child: _PlannedExerciseCard(
              planned: planned,
              isEditing: _isEditing,
              canMoveUp: index > 0,
              canMoveDown: index < routine.exercises.length - 1,
              onMove: (offset) =>
                  store.moveRoutineExercise(index, index + offset),
              onRemove: () => _remove(store, routine, index),
              isLighter:
                  !_isEditing &&
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
            label: '加入動作',
            onTap: () => _addExercises(context, routine),
          ),
        ),
        if (_isEditing)
          Gutter(
            child: Center(
              child: LinkText(
                label: '刪除這份課表',
                color: AppColors.destructive,
                onTap: () => _delete(routine),
              ),
            ),
          ),
        if (!_isEditing) ProgressionSection(routine: routine),
        if (store.recentRoutineWorkouts case final recent
            when recent.isNotEmpty) ...[
          Gutter(child: const SectionLabel('最近實際完成')),
          for (final workout in recent)
            Gutter(
              child: AccentRow(
                color: AppColors.training,
                title:
                    '${workout.startedAt.month} 月 ${workout.startedAt.day} 日'
                    '（週${weekdayLabel(workout.startedAt)}）',
                subtitle:
                    '${workout.completedSets} 組 · '
                    '${workout.elapsedAt(workout.finishedAt!).inMinutes} 分',
                showChevron: true,
                onTap: () => pushPage(
                  context,
                  WorkoutSummaryScreen(workoutId: workout.id),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// What the edit controls on a planned exercise do.
enum _PlanEdit {
  up('上移'),
  down('下移'),
  join('與下一個組成超級組'),
  leave('解除超級組'),
  remove('移除');

  const _PlanEdit(this.label);

  final String label;
}

class _PlannedExerciseCard extends StatelessWidget {
  const _PlannedExerciseCard({
    required this.planned,
    required this.isEditing,
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
  final bool isEditing;
  final bool canMoveUp;
  final bool canMoveDown;

  /// Done in turn with the exercise before or after it.
  final bool isInSuperset;

  /// Joins the exercise with the next one, or leaves that superset.
  final ValueChanged<bool> onJoinNext;

  /// Moves the exercise by the given offset in the plan.
  final ValueChanged<int> onMove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final qualifier = planned.isUnilateral
        ? '單邊'
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
              SizedBox(
                width: 56,
                child: qualifier == null
                    ? null
                    : Text(
                        qualifier,
                        textAlign: TextAlign.right,
                        style: AppTextStyles.caption,
                      ),
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
              if (isLighter) const TagChip(label: '今天少 1 組'),
              if (isInSuperset) ...[
                const SizedBox(width: AppSpacing.xs),
                const TagChip(label: '超級組', tone: TagTone.training),
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
                    label: '載入',
                    semanticLabel: '以上次的重量與次數填入',
                    onTap: () => onLoads([for (final _ in loads) last!]),
                  ),
          ),
          if (isEditing) ...[
            const SizedBox(height: AppSpacing.sm),
            ChipWrap(
              options: [
                if (canMoveUp) _PlanEdit.up,
                if (canMoveDown) _PlanEdit.down,
                if (canMoveDown)
                  planned.joinsNext ? _PlanEdit.leave : _PlanEdit.join,
                _PlanEdit.remove,
              ],
              labelOf: (edit) => edit.label,
              isSelected: (_) => false,
              onTap: (edit) => switch (edit) {
                _PlanEdit.up => onMove(-1),
                _PlanEdit.down => onMove(1),
                _PlanEdit.join => onJoinNext(true),
                _PlanEdit.leave => onJoinNext(false),
                _PlanEdit.remove => onRemove(),
              },
            ),
          ],
        ],
      ),
    );
  }
}
