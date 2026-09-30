import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../app/view_model.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/motion.dart';
import '../../shared/widgets/widgets.dart';
import '../activity/daily_activity_screen.dart';
import '../body/body_screen.dart';
import '../goal/goal_entry_button.dart';
import '../goal/goal_screen.dart';
import '../log/timeline_destination.dart';
import '../nutrition/daily_nutrition_screen.dart';
import '../nutrition/food_search_screen.dart';
import '../sleep/sleep_screen.dart';
import '../caffeine/caffeine_card.dart';
import '../caffeine/caffeine_screen.dart';
import '../training/workout_summary_screen.dart';
import '../water/water_screen.dart';
import '../trends/insight_detail_screen.dart';
import 'active_workout_today.dart';
import 'today_layout_screen.dart';
import 'today_view_model.dart';
import 'today_widgets.dart';
import '../../l10n/l10n.dart';

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
    final page = CollapsingPage(
      title: context.l10n.tabToday,
      subtitle: context.dates.dayWithWeekday(now),
      leading: const GoalEntryButton(),
      actions: [
        ?_healthReadStatus(context, store),
        HeaderAction(
          icon: Icons.tune,
          semanticLabel: context.l10n.customiseToday,
          onTap: () => pushPage(context, const TodayLayoutScreen()),
        ),
      ],
      children: [
        // A first read goes years back; a moving bar says the page is not
        // finished yet. The label above says it without the motion.
        if (store.isHealthReadSlow &&
            store.lastHealthSync == null &&
            !prefersReducedMotion(context))
          const Gutter(child: ProgressLine(progress: null, height: 4)),
        ...switch (store.activeSession) {
          ActiveWorkout() => buildActiveWorkoutToday(context, store),
          // The dock carries a running exercise and its controls; Today
          // goes on as usual beside it.
          ActiveActivity() || null => [
            ?_nextStep(context, store, today),
            ..._sections(context, store, today),
          ],
        },
      ],
    );
    if (!store.isHealthConnected) return page;
    return RefreshIndicator.adaptive(
      // Below the bar, where the page's content starts. Only the status
      // bar's inset is read, by its own aspect: the page's padding follows
      // the dock as it shrinks and grows while scrolling, and a page that
      // rebuilt with it would run every query on every frame.
      edgeOffset:
          MediaQuery.viewPaddingOf(context).top +
          ToolbarMetrics.of(context).height,
      onRefresh: () => _readHealthNow(context),
      child: page,
    );
  }

  /// What reading Apple Health or Health Connect is doing, on the bar,
  /// only when there is something to say: a spinner while a read is
  /// taking a while, or a warning icon when one failed, which a tap reads
  /// again. Bare, not on the bar's glass: they are states, not actions.
  /// A quick read and a good one say nothing; the figures that changed
  /// show it. Each is said once to a screen reader as it appears.
  Widget? _healthReadStatus(BuildContext context, AppStore store) {
    if (store.isHealthReadSlow) {
      return Semantics(
        liveRegion: true,
        label: context.l10n.healthReading,
        child: ExcludeSemantics(
          child: SizedBox.square(
            dimension: ToolbarMetrics.of(context).actionHitSize,
            child: const Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              ),
            ),
          ),
        ),
      );
    }
    if (store.isHealthConnected && store.healthSyncFailed) {
      final toolbar = ToolbarMetrics.of(context);
      return Semantics(
        liveRegion: true,
        child: Center(
          child: SquareIconButton(
            icon: Icons.error_outline,
            color: AppColors.warning,
            background: Colors.transparent,
            size: toolbar.actionHitSize,
            radius: toolbar.actionHitSize / 2,
            tooltip:
                '${context.l10n.healthReadFailedState} · ${context.l10n.retry}',
            onPressed: store.syncHealthInBackground,
          ),
        ),
      );
    }
    return null;
  }

  /// Pulled down: the same read the app runs on its own, joined if one is
  /// already going. Done is said only here, where the user asked for it;
  /// a failure is said by the bar.
  Future<void> _readHealthNow(BuildContext context) async {
    final store = AppStoreScope.read(context);
    final view = View.of(context);
    final direction = Directionality.of(context);
    final done = context.l10n.healthReadDone;
    await store.syncHealthInBackground();
    if (!store.healthSyncFailed) {
      SemanticsService.sendAnnouncement(view, done, direction);
    }
  }

  /// The one card that says what to do now, or nothing when there is
  /// nothing to do: the meal that usually comes about now, then the
  /// workout done today. What to train is not guessed: without a plan to
  /// follow, the app does not know what comes next.
  Widget? _nextStep(
    BuildContext context,
    AppStore store,
    TodayViewModel today,
  ) {
    final modules = store.enabledModules;
    final done = today.workoutToday;
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
    final onlyWithData = today.showsOnlyWithData;
    // A section with nothing today is left out, or, when every section is
    // to keep its place, shown as empty.
    // Still opening the section's own page, where the day is.
    void openPageOf(TodaySection section) => switch (section) {
      TodaySection.activity => pushPage(context, const DailyActivityScreen()),
      TodaySection.intake => pushPage(context, const DailyNutritionScreen()),
      TodaySection.caffeine => pushPage(context, const CaffeineScreen()),
      TodaySection.vitals => pushPage(context, const BodyScreen()),
      TodaySection.insights => pushPage(context, const InsightDetailScreen()),
      _ => store.selectTab(HomeTab.log),
    };
    List<Widget> orEmpty(
      TodaySection section,
      Color color,
      List<Widget> content,
    ) => content.isNotEmpty || onlyWithData
        ? content
        : [
            Gutter(
              child: EmptySectionCard(
                label: section.labelIn(context.l10n),
                color: color,
                onTap: () => openPageOf(section),
              ),
            ),
          ];
    List<Widget> sectionOf(TodaySection section) => switch (section) {
      TodaySection.glance => _glance(context, store, today, modules),
      TodaySection.activity when modules.contains(AppModule.activity) =>
        orEmpty(section, AppColors.activity, [?_activity(context, today)]),
      TodaySection.intake when modules.contains(AppModule.nutrition) => orEmpty(
        section,
        AppColors.nutrition,
        [
          if (store.todaySummary.recordCount > 0)
            Gutter(
              child: IntakeCard(
                store: store,
                onTap: () => pushPage(context, const DailyNutritionScreen()),
              ),
            ),
        ],
      ),
      TodaySection.caffeine when modules.contains(AppModule.nutrition) =>
        orEmpty(section, AppColors.caffeine, [
          if (today.caffeine case (:final curve, :final nowIndex))
            Gutter(
              child: CaffeineCard(
                curve: curve,
                nowIndex: nowIndex,
                onTap: () => pushPage(context, const CaffeineScreen()),
              ),
            ),
        ]),
      TodaySection.vitals when modules.contains(AppModule.weight) => orEmpty(
        section,
        AppColors.body,
        [
          // Only a vital taken on purpose earns the card, unless every
          // section is kept: then whatever was read shows, never "none".
          if (today.vitals case final vitals
              when vitals.isNotEmpty &&
                  (!onlyWithData || TodayViewModel.isTaken(vitals)))
            Gutter(
              child: VitalsCard(
                vitals: vitals,
                onTap: () => pushPage(context, const BodyScreen()),
              ),
            ),
        ],
      ),
      TodaySection.week
          when modules.contains(AppModule.training) ||
              modules.contains(AppModule.activity) =>
        _week(context, store, today),
      TodaySection.records => orEmpty(
        section,
        AppColors.textSecondary,
        _records(context, today),
      ),
      TodaySection.insights => orEmpty(section, AppColors.wellness, [
        if (store.todayInsights.isNotEmpty)
          PageSection(
            label: TodaySection.insights.labelIn(context.l10n),
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
      ]),
      _ => const [],
    };
    return [
      for (final section in today.order)
        if (!hidden.contains(section)) ...sectionOf(section),
    ];
  }

  List<Widget> _glance(
    BuildContext context,
    AppStore store,
    TodayViewModel today,
    Set<AppModule> modules,
  ) {
    final water = today.water;
    final waterReference = today.waterReferenceMl;
    final night = store.lastNight;
    final sleepGoal = today.sleepGoal;
    final tiles = [
      if (modules.contains(AppModule.sleep))
        QuickStatTile(
          category: context.l10n.moduleSleep,
          color: AppColors.wellness,
          value: night == null
              ? null
              : formatHoursMinutes(night.entry.duration),
          visual: night != null && sleepGoal != null
              ? ProgressLine(
                  progress:
                      night.entry.duration.inMinutes / sleepGoal.inMinutes,
                  color: AppColors.wellness,
                  height: 4,
                )
              : null,
          caption: switch (night) {
            null => null,
            _ when sleepGoal != null => context.l10n.goalValue(
              goal: formatHoursMinutes(sleepGoal),
            ),
            final night when night.isTypedIn => context.l10n.sourceManual,
            final night =>
              night.entry.sourceName.isEmpty
                  ? store.healthSourceName
                  : night.entry.sourceName,
          },
          onTap: () => pushPage(context, const SleepScreen()),
        ),
      if (modules.contains(AppModule.weight)) const _WeightTile(),
      if (modules.contains(AppModule.water))
        QuickStatTile(
          category: context.l10n.healthDataWater,
          color: AppColors.water,
          value: water.times == 0 ? null : formatKcal(water.millilitres),
          unit: switch (waterReference) {
            final reference? => '/ ${formatKcal(reference)} mL',
            null => 'mL',
          },
          // Up to the reference and no further: past it the tile stays
          // full rather than rewarding more.
          level: switch (waterReference) {
            final reference? when reference > 0 =>
              water.millilitres / reference,
            _ => null,
          },
          motion: store.motion.acceleration,
          caption: water.times == 0
              ? null
              : context.l10n.timesCount(count: water.times),
          onTap: () => pushPage(context, const WaterScreen()),
        ),
    ];
    if (tiles.isEmpty) return const [];
    return [
      Gutter(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, tile) in tiles.indexed) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xs),
                Expanded(child: tile),
              ],
            ],
          ),
        ),
      ),
    ];
  }

  /// Today's movement, when the health platform counted any.
  Widget? _activity(BuildContext context, TodayViewModel today) {
    final totals = today.activityTotals;
    final lead = ActivityMetric.headline.where(totals.containsKey).firstOrNull;
    if (lead == null) return null;
    return Gutter(
      child: TodayActivityCard(
        lead: lead,
        totals: totals,
        hours: today.activityHours(lead) ?? List.filled(24, 0),
        onTap: () => pushPage(context, const DailyActivityScreen()),
      ),
    );
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
          TodaySection.week.labelIn(context.l10n),
          trailing: Text(
            target == null
                ? context.l10n.daysCount(count: active)
                : context.l10n.daysFraction(active: active, target: target),
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

  /// The latest records of today across the app, oldest first, and the
  /// way to the rest in 紀錄; nothing at all on a day without any.
  List<Widget> _records(BuildContext context, TodayViewModel today) {
    const shown = 4;
    final all = today.records;
    if (all.isEmpty) return const [];
    final records = all.skip(all.length > shown ? all.length - shown : 0);
    return [
      Gutter(
        child: SectionLabel(
          TodaySection.records.labelIn(context.l10n),
          trailing: all.length > shown
              ? LinkText(
                  label: context.l10n.allCount(count: all.length),
                  onTap: () =>
                      AppStoreScope.read(context).selectTab(HomeTab.log),
                )
              : null,
        ),
      ),
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
                  mealById: today.backend.nutrition.mealById,
                )) {
                  final page? => () => pushPage(context, page),
                  null => null,
                },
              ),
          ],
        ),
      ),
    ];
  }
}

class _WeightTile extends StatelessWidget {
  const _WeightTile();

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final (:latest, :weekTrend, :weekChange) = store.weightSummary;
    return QuickStatTile(
      category: context.l10n.moduleWeight,
      color: AppColors.body,
      value: latest == null ? null : formatWeight(latest.weightKg),
      unit: 'kg',
      visual: weekTrend.length < 2
          ? null
          : Sparkline(values: weekTrend, color: AppColors.body, height: 20),
      caption: switch ((latest, weekChange)) {
        (null, _) => null,
        (_, final change?) => context.l10n.weightChange7Days(
          change:
              '${change < 0 ? '−' : '+'}${formatWeight((change.abs() * 10).round() / 10)}',
        ),
        _ => context.dates.compactMonthDay(latest!.measuredAt),
      },
      onTap: () => pushPage(context, const BodyScreen()),
    );
  }
}
