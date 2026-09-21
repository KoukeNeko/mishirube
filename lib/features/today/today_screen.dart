import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../goal/goal_entry_button.dart';
import '../nutrition/daily_nutrition_screen.dart';
import '../nutrition/food_search_screen.dart';
import '../training/active_workout_screen.dart';
import '../training/routine_detail_screen.dart';
import '../training/workout_summary_screen.dart';
import '../trends/insight_detail_screen.dart';
import 'active_workout_today.dart';
import 'today_widgets.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final isWorkoutActive = store.activeWorkout != null;
    final phaseLabel = isWorkoutActive ? '19:42' : store.phase.label;
    return CollapsingPage(
      title: '今天',
      subtitle: '9 月 19 日・週六・$phaseLabel',
      leading: const GoalEntryButton(),
      actions: [
        // Mock-only: the date button walks through the day's scenarios.
        HeaderAction(
          icon: Icons.calendar_today_outlined,
          label: '9/19',
          semanticLabel: '切換示範時段，目前$phaseLabel',
          onTap: isWorkoutActive ? null : store.cyclePhase,
        ),
      ],
      children: isWorkoutActive
          ? buildActiveWorkoutToday(context, store)
          : switch (store.phase) {
              DayPhase.morning => _morning(context, store),
              DayPhase.noon => _noon(context, store),
              DayPhase.evening => _evening(context, store),
            },
    );
  }

  List<Widget> _morning(BuildContext context, AppStore store) {
    final routine = store.routine;
    return [
      Gutter(child: const WeekStrip()),
      Gutter(
        child: NextWorkoutCard(
          routine: routine,
          onStart: () => startWorkoutFlow(context),
          onOpenRoutine: () => pushPage(context, const RoutineDetailScreen()),
        ),
      ),
      Gutter(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Expanded(child: _WeightTile()),
              const SizedBox(width: AppSpacing.xs),
              const Expanded(
                child: QuickStatTile(
                  category: '睡眠',
                  color: AppColors.wellness,
                  value: '6:52',
                  caption: 'Apple Health',
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: QuickActionTile(
                  category: '飲食',
                  color: AppColors.nutrition,
                  action: '記錄早餐',
                  caption: '今天還沒有紀錄',
                  onTap: () => pushPage(context, const FoodSearchScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
      ..._activities(store),
      for (final insight in store.todayInsights)
        Gutter(
          child: InsightCard(
            insight: insight,
            onTap: () => pushPage(context, const InsightDetailScreen()),
          ),
        ),
    ];
  }

  List<Widget> _noon(BuildContext context, AppStore store) {
    return [
      if (!store.isLunchLogged)
        Gutter(
          child: NextMealCard(
            onSearch: () => pushPage(context, const FoodSearchScreen()),
          ),
        ),
      Gutter(
        child: IntakeCard(
          store: store,
          onTap: () => pushPage(context, const DailyNutritionScreen()),
        ),
      ),
      Gutter(
        child: AccentRow(
          color: AppColors.training,
          title: store.routine.name,
          subtitle: '今晚的訓練',
          showChevron: true,
          onTap: () => pushPage(context, const RoutineDetailScreen()),
        ),
      ),
    ];
  }

  List<Widget> _evening(BuildContext context, AppStore store) {
    return [
      Gutter(child: const WeekStrip()),
      Gutter(
        child: NextActionCard(
          title: '記錄晚餐',
          message: '訓練後還沒有任何飲食紀錄',
          buttonLabel: '記錄晚餐',
          onTap: () => pushPage(context, const FoodSearchScreen()),
        ),
      ),
      Gutter(
        child: CompletedWorkoutCard(
          workout: store.lastFinishedWorkout,
          onTap: () => pushPage(context, const WorkoutSummaryScreen()),
        ),
      ),
      Gutter(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: QuickStatTile(
                  category: '飲食',
                  color: AppColors.nutrition,
                  value: formatKcal(store.todayKcal),
                  unit: 'kcal',
                  caption: [
                    '${store.todaySummary.mealCount} 餐',
                    if (store.todaySummary.hasEstimates) '含估計值',
                  ].join(' · '),
                  onTap: () => pushPage(context, const DailyNutritionScreen()),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Expanded(child: _WeightTile()),
            ],
          ),
        ),
      ),
      ..._activities(store),
      for (final insight in store.todayInsights)
        Gutter(child: InsightCard(insight: insight)),
    ];
  }

  /// Exercise logged today sits with the training it belongs beside, and
  /// disappears entirely on a day without any: it is a record, not a card
  /// the screen owes the user.
  List<Widget> _activities(AppStore store) => [
    for (final activity in store.activitiesOn(store.now()))
      Gutter(
        child: AccentRow(
          color: AppColors.activity,
          title: activity.type.label,
          subtitle: activity.description,
        ),
      ),
  ];
}

class _WeightTile extends StatelessWidget {
  const _WeightTile();

  @override
  Widget build(BuildContext context) {
    return const QuickStatTile(
      category: '體重',
      color: AppColors.body,
      value: '72.4',
      unit: 'kg',
      caption: '7 日 −0.3',
    );
  }
}
