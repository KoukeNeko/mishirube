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
class RoutineDetailScreen extends StatelessWidget {
  const RoutineDetailScreen({super.key});

  Future<void> _addExercises(BuildContext context, Routine routine) async {
    final store = AppStoreScope.read(context);
    final selected = await pushModalPage<List<ExerciseDefinition>>(
      context,
      ExercisePickerScreen(targetName: routine.name, isTemplate: true),
    );
    if (selected == null || selected.isEmpty) return;
    store.addExercises(selected);
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
        Gutter(child: const SectionLabel('計畫的動作')),
        for (final planned in routine.exercises)
          Gutter(child: _PlannedExerciseCard(planned: planned)),
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

class _PlannedExerciseCard extends StatelessWidget {
  const _PlannedExerciseCard({required this.planned});

  final PlannedExercise planned;

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
        ],
      ),
    );
  }
}
