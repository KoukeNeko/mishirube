import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../shared/format.dart';
import '../../shared/widgets/elapsed_clock.dart';
import '../../shared/widgets/widgets.dart';
import '../nutrition/daily_nutrition_screen.dart';
import '../training/active_workout_screen.dart';

/// Today while a workout runs: insights pause, only facts are shown.
List<Widget> buildActiveWorkoutToday(BuildContext context, AppStore store) {
  final workout = store.activeWorkout!;
  final current = workout.currentExercise;
  final progress = workout.totalSets == 0
      ? 0.0
      : workout.completedSets / workout.totalSets;
  return [
    AppCard(
      tone: CardTone.training,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CategoryLabel(label: '訓練進行中', color: AppColors.training),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  workout.routineName,
                  style: AppTextStyles.cardTitle,
                ),
              ),
              ElapsedClock(
                workout: workout,
                builder: (_, elapsed) => Text(
                  elapsed,
                  style: AppTextStyles.hugeNumber.copyWith(
                    color: AppColors.training,
                  ),
                ),
              ),
            ],
          ),
          Text(
            '${current.exercise.name} · 第 ${(current.nextSetIndex ?? current.sets.length - 1) + 1} 組'
            ' · 已完成 ${workout.completedSets} 組',
            style: AppTextStyles.caption.copyWith(fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.md),
          ProgressLine(progress: progress),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: '返回訓練',
            onPressed: () => pushPage(context, const ActiveWorkoutScreen()),
          ),
        ],
      ),
    ),
    AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('本次到目前', style: AppTextStyles.overline),
          const SizedBox(height: AppSpacing.sm),
          StatRow(
            stats: [
              StatBlock(value: '${workout.completedSets}', label: '已完成組數'),
              StatBlock(
                value:
                    '${workout.completedExercises}/${workout.exercises.length}',
                label: '動作進度',
              ),
              StatBlock(
                value: '${workout.personalRecords}',
                label: '新的個人紀錄',
                valueColor: AppColors.training,
              ),
            ],
          ),
        ],
      ),
    ),
    const SectionLabel('其他紀錄'),
    AccentRow(
      color: AppColors.nutrition,
      title: '飲食',
      trailing:
          '${store.todayMeals.length} 餐 · ~${formatKcal(store.todayKcal)} kcal',
      onTap: () => pushPage(context, const DailyNutritionScreen()),
    ),
    const AccentRow(color: AppColors.body, title: '體重', trailing: '72.4 kg'),
    const AccentRow(
      color: AppColors.wellness,
      title: '睡眠',
      trailing: '6 小時 52 分',
    ),
    const Text('訓練結束前，洞察與建議暫停顯示。', style: AppTextStyles.caption),
  ];
}
