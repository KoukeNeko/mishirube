import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_picker_screen.dart';
import 'active_workout_screen.dart';
import 'workout_summary_screen.dart';

/// A workout template (plan). Editing it never rewrites finished workouts.
class RoutineDetailScreen extends StatefulWidget {
  const RoutineDetailScreen({super.key});

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  /// Editing shows the controls that change the plan's shape, so a tap
  /// while browsing cannot reorder or remove anything.
  bool _isEditing = false;

  Future<void> _addExercises(BuildContext context, Routine routine) async {
    final store = AppStoreScope.read(context);
    final selected = await pushModalPage<List<ExerciseDefinition>>(
      context,
      ExercisePickerScreen(targetName: routine.name, isTemplate: true),
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
    final controller = TextEditingController(text: routine.name);
    final name = await showAppDialog<String>(
      context,
      AppDialog(
        title: '訓練名稱',
        content: AppTextField(controller: controller, autofocus: true),
        actions: [
          DialogAction(
            label: '儲存',
            tone: DialogTone.primary,
            onTap: () => Navigator.of(context).pop(controller.text.trim()),
          ),
          DialogAction(label: '取消', onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    AppStoreScope.read(context).renameRoutine(name);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final routine = store.routine;
    final isWorkoutActive = store.activeWorkout != null;
    return DetailPage(
      appBar: PageAppBar(
        title: routine.name,
        subtitle: '訓練模板 · ${routine.programName}',
        actions: [
          HeaderAction(
            icon: _isEditing ? Icons.check : Icons.edit_outlined,
            label: _isEditing ? '完成' : '編輯',
            semanticLabel: _isEditing ? '完成編輯' : '編輯這份訓練',
            onTap: () => setState(() => _isEditing = !_isEditing),
          ),
        ],
      ),
      footer: PrimaryButton(
        label: isWorkoutActive ? '返回訓練' : '開始訓練',
        icon: Icons.play_arrow_outlined,
        onPressed: () {
          store.startWorkout();
          replaceWithPage(context, const ActiveWorkoutScreen());
        },
      ),
      children: [
        Gutter(
          child: const InfoBanner(message: '修改這份訓練模板只會影響之後的訓練，已完成的訓練紀錄不會被改寫。'),
        ),
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
            ),
          ),
        Gutter(
          child: DashedActionCard(
            label: '加入動作',
            onTap: () => _addExercises(context, routine),
          ),
        ),
        Gutter(child: const SectionLabel('最近實際完成')),
        Gutter(
          child: AccentRow(
            color: AppColors.training,
            title: '9 月 16 日',
            subtitle: '16 組 · 54 分',
            showChevron: true,
            onTap: () => pushPage(context, const WorkoutSummaryScreen()),
          ),
        ),
        Gutter(
          child: const AccentRow(
            color: AppColors.training,
            title: '9 月 12 日',
            subtitle: '16 組 · 57 分',
          ),
        ),
      ],
    );
  }
}

/// What the edit controls on a planned exercise do.
enum _PlanEdit {
  up('上移'),
  down('下移'),
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
  });

  final PlannedExercise planned;
  final bool isEditing;
  final bool canMoveUp;
  final bool canMoveDown;

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
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
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
              Text(
                '${planned.sets} × ${planned.reps}',
                style: AppTextStyles.bigNumber.copyWith(fontSize: 22),
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
              Text(
                planned.progressionLabel,
                style: const TextStyle(
                  color: AppColors.training,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (isEditing) ...[
            const SizedBox(height: AppSpacing.sm),
            ChipWrap(
              options: [
                if (canMoveUp) _PlanEdit.up,
                if (canMoveDown) _PlanEdit.down,
                _PlanEdit.remove,
              ],
              labelOf: (edit) => edit.label,
              isSelected: (_) => false,
              onTap: (edit) => switch (edit) {
                _PlanEdit.up => onMove(-1),
                _PlanEdit.down => onMove(1),
                _PlanEdit.remove => onRemove(),
              },
            ),
          ],
        ],
      ),
    );
  }
}
