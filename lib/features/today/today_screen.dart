import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../app/view_model.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../body/body_screen.dart';
import '../goal/goal_entry_button.dart';
import '../goal/goal_screen.dart';
import '../log/timeline_destination.dart';
import '../nutrition/daily_nutrition_screen.dart';
import '../nutrition/food_search_screen.dart';
import '../sleep/sleep_screen.dart';
import '../training/active_workout_screen.dart';
import '../training/routine_detail_screen.dart';
import '../training/workout_summary_screen.dart';
import '../trends/insight_detail_screen.dart';
import 'active_workout_today.dart';
import 'today_layout_screen.dart';
import 'today_view_model.dart';
import 'today_widgets.dart';

/// Today, in the order the day asks its questions (see
/// `research/46-today-home.md`): what is under way, the one next step,
/// today's figures, what was recorded, and what is worth noticing.
///
/// The frame stays put; only the next step changes, and it changes with
/// what happened — a workout done, a meal logged — not with the clock
/// alone. Nothing is shown for a module that is off, and a figure with
/// no record says so instead of reading zero.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) => ViewModelBuilder(
    create: TodayViewModel.new,
    builder: (context, today) => _page(context, today),
  );

  Widget _page(BuildContext context, TodayViewModel today) {
    final store = AppStoreScope.of(context);
    final now = store.now();
    return CollapsingPage(
      title: '今天',
      subtitle: '${now.month} 月 ${now.day} 日（週${weekdayLabel(now)}）',
      leading: const GoalEntryButton(),
      actions: [
        HeaderAction(
          icon: Icons.tune,
          semanticLabel: '自訂首頁',
          onTap: () => pushPage(context, const TodayLayoutScreen()),
        ),
      ],
      children: switch (store.activeSession) {
        ActiveWorkout() => buildActiveWorkoutToday(context, store),
        // The dock carries a running exercise and its controls; Today
        // goes on as usual beside it.
        ActiveActivity() || null => [
          ?_nextStep(context, store, today),
          ..._sections(context, store, today),
        ],
      },
    );
  }

  /// The one card that says what to do now, or nothing when there is
  /// nothing to do: training not yet done today, then the meal that
  /// usually comes about now, then the workout done today.
  Widget? _nextStep(
    BuildContext context,
    AppStore store,
    TodayViewModel today,
  ) {
    final modules = store.enabledModules;
    final done = today.workoutToday;
    if (modules.contains(AppModule.training) && done == null) {
      return Gutter(
        child: NextWorkoutCard(
          routine: store.routine,
          onStart: () => startWorkoutFlow(context),
          onOpenRoutine: () => pushPage(context, const RoutineDetailScreen()),
        ),
      );
    }
    if (modules.contains(AppModule.nutrition)) {
      if (today.nextMeal case final meal?) {
        return Gutter(
          child: NextMealCard(
            mealType: meal,
            onLog: () => pushPage(context, const FoodSearchScreen()),
          ),
        );
      }
    }
    if (done != null) {
      return Gutter(
        child: CompletedWorkoutCard(
          workout: done,
          onTap: () =>
              pushPage(context, WorkoutSummaryScreen(workoutId: done.id)),
        ),
      );
    }
    return null;
  }

  List<Widget> _sections(
    BuildContext context,
    AppStore store,
    TodayViewModel today,
  ) {
    final hidden = today.hidden;
    final modules = store.enabledModules;
    return [
      if (!hidden.contains(TodaySection.glance))
        ..._glance(context, store, today, modules),
      if (!hidden.contains(TodaySection.intake) &&
          modules.contains(AppModule.nutrition) &&
          store.todaySummary.recordCount > 0)
        Gutter(
          child: IntakeCard(
            store: store,
            onTap: () => pushPage(context, const DailyNutritionScreen()),
          ),
        ),
      if (!hidden.contains(TodaySection.week) &&
          (modules.contains(AppModule.training) ||
              modules.contains(AppModule.activity)))
        ..._week(context, store, today),
      if (!hidden.contains(TodaySection.records)) ..._records(context, today),
      if (!hidden.contains(TodaySection.insights) &&
          store.todayInsights.isNotEmpty)
        PageSection(
          label: TodaySection.insights.label,
          children: [
            for (final insight in store.todayInsights)
              Gutter(
                child: InsightCard(
                  insight: insight,
                  onTap: () => pushPage(context, const InsightDetailScreen()),
                ),
              ),
          ],
        ),
    ];
  }

  /// A tile for each figure an enabled module keeps, as a grid that adds
  /// columns when it has room.
  List<Widget> _glance(
    BuildContext context,
    AppStore store,
    TodayViewModel today,
    Set<AppModule> modules,
  ) {
    final water = today.water;
    final tiles = [
      if (modules.contains(AppModule.sleep))
        QuickStatTile(
          category: '睡眠',
          color: AppColors.wellness,
          value: switch (store.lastNight) {
            final night? => formatHoursMinutes(night.entry.duration),
            null => '—',
          },
          caption: switch (store.lastNight) {
            null => '沒有紀錄',
            final night when night.isTypedIn => '手動輸入',
            final night =>
              night.entry.sourceName.isEmpty
                  ? store.healthSourceName
                  : night.entry.sourceName,
          },
          onTap: () => pushPage(context, const SleepScreen()),
        ),
      if (modules.contains(AppModule.weight)) const _WeightTile(),
      if (modules.contains(AppModule.nutrition))
        QuickStatTile(
          category: '喝水',
          color: AppColors.nutrition,
          value: water.times == 0
              ? '—'
              : formatAmount(water.millilitres.toDouble()),
          unit: water.times == 0 ? null : 'mL',
          caption: water.times == 0 ? '沒有紀錄' : '${water.times} 次',
          onTap: () => pushPage(context, const DailyNutritionScreen()),
        ),
    ];
    if (tiles.isEmpty) return const [];
    return [
      Gutter(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const minTileWidth = 104.0;
            final columns = (constraints.maxWidth / minTileWidth).floor().clamp(
              1,
              tiles.length,
            );
            final width =
                (constraints.maxWidth - AppSpacing.xs * (columns - 1)) /
                columns;
            return Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final tile in tiles) SizedBox(width: width, child: tile),
              ],
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _week(
    BuildContext context,
    AppStore store,
    TodayViewModel today,
  ) {
    final (:days, :active, :target) = today.week;
    final now = store.now();
    return [
      Gutter(
        child: SectionLabel(
          TodaySection.week.label,
          trailing: Text(
            target == null ? '$active 天' : '$active / $target 天',
            style: AppTextStyles.caption,
          ),
        ),
      ),
      Gutter(
        child: WeekStrip(
          days: days,
          today: DateTime(now.year, now.month, now.day),
          onTap: () => pushPage(context, const GoalScreen()),
        ),
      ),
    ];
  }

  /// Every record of today across the app, oldest first; nothing at all
  /// on a day without any.
  List<Widget> _records(BuildContext context, TodayViewModel today) {
    final records = today.records;
    if (records.isEmpty) return const [];
    return [
      PageSection(
        label: TodaySection.records.label,
        children: [
          Gutter(
            child: GroupedCard(
              children: [
                for (final entry in records)
                  NavRow(
                    leading: AccentBar(color: entry.category.color, height: 28),
                    title: entry.title,
                    subtitle: [
                      entry.timeLabel,
                      if (entry.detail.isNotEmpty) entry.detail,
                    ].join(' · '),
                    onTap: switch (timelineDestination(
                      entry,
                      isSleep: today.isSleep,
                    )) {
                      final page? => () => pushPage(context, page),
                      null => null,
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    ];
  }
}

class _WeightTile extends StatelessWidget {
  const _WeightTile();

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final (:latest, :weekChange) = store.weightSummary;
    return QuickStatTile(
      category: '體重',
      color: AppColors.body,
      value: latest == null ? '—' : formatWeight(latest.weightKg),
      unit: latest == null ? null : 'kg',
      caption: switch ((latest, weekChange)) {
        (null, _) => '沒有紀錄',
        (_, final change?) =>
          '7 日 ${change < 0 ? '−' : '+'}${formatWeight((change.abs() * 10).round() / 10)}',
        _ => '${latest!.measuredAt.month}/${latest.measuredAt.day}',
      },
      onTap: () => pushPage(context, const BodyScreen()),
    );
  }
}
