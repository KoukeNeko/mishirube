import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../app/app_store.dart';
import '../../app/caffeine_activity.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../app/view_model.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/motion.dart';
import '../../shared/widgets/widgets.dart';
import '../activity/daily_activity_screen.dart';
import '../body/body_screen.dart';
import '../body/weight_trend_chart.dart';
import '../goal/goal_entry_button.dart';
import '../goal/goal_screen.dart';
import '../log/timeline_destination.dart';
import '../nutrition/daily_nutrition_screen.dart';
import '../nutrition/food_search_screen.dart';
import '../bath/bath_screen.dart';
import '../sleep/sleep_screen.dart';
import '../caffeine/caffeine_card.dart';
import '../caffeine/caffeine_screen.dart';
import '../training/workout_summary_screen.dart';
import '../water/water_screen.dart';
import '../trends/insight_destination.dart';
import '../trends/usual_range_trend.dart';
import '../vitals/vitals_screen.dart';
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
    final page = CollapsingPage(
      title: today.isToday
          ? context.l10n.tabToday
          : context.dates.dayWithWeekday(today.day),
      subtitle: today.isToday ? context.dates.dayWithWeekday(today.day) : null,
      leading: const GoalEntryButton(),
      actions: [
        ?_healthReadStatus(context, store),
        if (!today.isToday)
          HeaderAction(
            icon: Icons.today_outlined,
            label: context.l10n.tabToday,
            semanticLabel: context.l10n.backToToday,
            onTap: () => today.pick(today.today),
          ),
        HeaderAction(
          icon: Icons.tune,
          semanticLabel: context.l10n.customiseToday,
          onTap: () => pushPage(context, const TodayLayoutScreen()),
        ),
      ],
      // Any day is a swipe away, as on 飲食 and 睡眠.
      pinned: WeekDayStrip(
        selected: today.day,
        latest: today.today,
        firstWeekday: store.firstWeekday,
        markedDays: today.markedDays,
        onSelected: today.pick,
      ),
      pinnedHeight: WeekDayStrip.pinnedHeightOf(context),
      // Out of the way while reading down; back on the way up, and at the top.
      hidesPinnedOnScroll: true,
      children: [
        // A first read goes years back; a moving bar says the page is not
        // finished yet. The label above says it without the motion.
        if (store.isHealthReadSlow &&
            store.lastHealthSync == null &&
            !prefersReducedMotion(context))
          const Gutter(child: ProgressLine(progress: null, height: 4)),
        ...switch (store.activeSession) {
          ActiveWorkout() when today.isToday => buildActiveWorkoutToday(
            context,
            store,
          ),
          // The dock carries a running exercise and its controls; Today
          // goes on as usual beside it, and so does another day.
          _ => [
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
  /// workouts done on the day, swiped when there were several. What to train
  /// is not guessed: without a plan to follow, the app does not know what
  /// comes next.
  Widget? _nextStep(
    BuildContext context,
    AppStore store,
    TodayViewModel today,
  ) {
    final modules = store.enabledModules;
    final done = today.workouts;
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
    if (done.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xs,
        children: [
          Gutter(
            child: CategoryHeading(
              label: context.l10n.moduleTraining,
              color: AppColors.training,
            ),
          ),
          CardPager(
            children: [
              for (final workout in done)
                CompletedWorkoutCard(
                  workout: workout,
                  onTap: () => pushPage(
                    context,
                    WorkoutSummaryScreen(workoutId: workout.id),
                  ),
                ),
            ],
          ),
        ],
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
      TodaySection.activity => pushPage(
        context,
        DailyActivityScreen(day: today.day),
      ),
      TodaySection.intake => pushPage(
        context,
        DailyNutritionScreen(day: today.day),
      ),
      TodaySection.caffeine => pushPage(context, const CaffeineScreen()),
      TodaySection.vitals => pushPage(context, const VitalsScreen()),
      TodaySection.insights => store.selectTab(HomeTab.trends),
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
                label: section.labelIn(context.l10n, isToday: today.isToday),
                color: color,
                onTap: () => openPageOf(section),
              ),
            ),
          ];
    List<Widget> sectionOf(TodaySection section) => switch (section) {
      TodaySection.activity when modules.contains(AppModule.activity) =>
        orEmpty(section, AppColors.activity, [?_activity(context, today)]),
      // Eating and drinking are one category: the water joins the meals,
      // or stands alone under the same name when nothing was eaten.
      TodaySection.intake
          when modules.contains(AppModule.nutrition) ||
              modules.contains(AppModule.water) =>
        switch ((
          modules.contains(AppModule.nutrition) && today.intake.recordCount > 0,
          modules.contains(AppModule.water)
              ? _waterSegment(context, store, today)
              : null,
        )) {
          (true, final water) => [
            Gutter(
              child: IntakeCard(
                summary: today.intake,
                convention: today.backend.nutrition.convention,
                kcalTarget: today.kcalTarget,
                onTap: () =>
                    pushPage(context, DailyNutritionScreen(day: today.day)),
                extraRows: [
                  if (water != null) [water],
                ],
              ),
            ),
          ],
          (false, final water?) => [
            Gutter(
              child: CategoryGroup(
                label: TodaySection.intake.labelIn(context.l10n),
                color: AppColors.nutrition,
                children: [
                  SegmentedGroup(
                    rows: [
                      [water],
                    ],
                  ),
                ],
              ),
            ),
          ],
          (false, null) => orEmpty(section, AppColors.nutrition, const []),
        },
      TodaySection.sleep when modules.contains(AppModule.sleep) => [
        Gutter(
          child: CategoryGroup(
            label: TodaySection.sleep.labelIn(context.l10n),
            color: AppColors.wellness,
            children: [
              SegmentedGroup(
                rows: [
                  [
                    _sleepSegment(context, store, today),
                    _bathSegment(context, today),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
      TodaySection.body when modules.contains(AppModule.weight) => [
        Gutter(
          child: CategoryGroup(
            label: TodaySection.body.labelIn(context.l10n),
            color: AppColors.body,
            children: [
              SegmentedGroup(
                rows: [
                  [_weightSegment(context, today.weight)],
                ],
              ),
            ],
          ),
        ),
      ],
      // What is in the body now means nothing of another day.
      TodaySection.caffeine
          when modules.contains(AppModule.nutrition) && today.isToday =>
        orEmpty(section, AppColors.caffeine, [
          if (today.caffeine case (:final curve, :final nowIndex))
            Gutter(
              child: CategoryGroup(
                label: context.l10n.nutrientCaffeine,
                color: AppColors.caffeine,
                tag: switch (CaffeineActivityScope.maybeOf(context)) {
                  final liveActivity? when liveActivity.isShowing => ChipButton(
                    label: context.l10n.endLiveActivity,
                    onTap: liveActivity.end,
                  ),
                  _ => null,
                },
                children: [
                  CaffeineCard(
                    curve: curve,
                    nowIndex: nowIndex,
                    onTap: () => pushPage(context, const CaffeineScreen()),
                  ),
                ],
              ),
            ),
        ]),
      // Read from the health platform, as activity is.
      TodaySection.vitals when modules.contains(AppModule.activity) => orEmpty(
        section,
        AppColors.heart,
        [
          // What the user pinned, or only what
          // [TodayViewModel.earnsCard] allows, unless every section is
          // kept: then whatever was read shows, never "none".
          if (today.vitalReadings case final readings
              when readings.isNotEmpty &&
                  (today.hasPinnedVitals ||
                      !onlyWithData ||
                      TodayViewModel.earnsCard(today.vitals)))
            Gutter(
              child: VitalsCard(
                readings: readings,
                today: today.day,
                weekOf: (metric, day) => ReadingWeek(
                  metric: metric,
                  day: day,
                  recent: (metric) => today.daily(
                    metric,
                    day.subtract(UsualRangeSpark.reach),
                    day,
                  ),
                  width: 72,
                  height: 24,
                ),
                onTap: () => pushPage(context, const VitalsScreen()),
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
      TodaySection.insights when today.isToday => orEmpty(
        section,
        AppColors.wellness,
        [
          if (store.todayInsights.isNotEmpty)
            Gutter(
              child: CategoryGroup(
                label: TodaySection.insights.labelIn(context.l10n),
                color: AppColors.wellness,
                children: [
                  SegmentedGroup(
                    rows: [
                      for (final insight in store.todayInsights)
                        [
                          Segment(
                            onTap: switch (insightDestination(insight)) {
                              final page? => () => pushPage(context, page),
                              null => null,
                            },
                            child: Padding(
                              padding: segmentPadding,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    insight.statement,
                                    style: AppTextStyles.body.copyWith(
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  TagWrap(labels: insight.evidence),
                                ],
                              ),
                            ),
                          ),
                        ],
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
      _ => const [],
    };
    return [
      for (final section in today.order)
        if (!hidden.contains(section)) ...sectionOf(section),
    ];
  }

  Segment _sleepSegment(
    BuildContext context,
    AppStore store,
    TodayViewModel today,
  ) {
    final night = today.night;
    final sleepGoal = today.sleepGoal;
    final napTime = today.napTimeOn(night?.entry.sleptAt ?? today.day);
    return Segment(
      onTap: () => pushPage(context, SleepScreen(day: today.day)),
      child: SegmentStat(
        label: context.l10n.moduleSleep,
        color: AppColors.wellness,
        mark: (tint) => Icon(Icons.bedtime_outlined, size: 16, color: tint),
        placeholder: context.l10n.noEntriesShort,
        value: night == null
            ? null
            : formatDuration(context.l10n, night.entry.duration),
        // Time in bed is not measured against a goal for sleep, as the
        // sleep page does not.
        progress:
            night != null &&
                sleepGoal != null &&
                night.entry.measure == SleepMeasure.asleep
            ? night.entry.duration.inMinutes / sleepGoal.inMinutes
            : null,
        caption: switch (night) {
          _ when napTime > Duration.zero => context.l10n.withNapsTotal(
            time: formatDuration(
              context.l10n,
              (night?.entry.duration ?? Duration.zero) + napTime,
            ),
          ),
          null => null,
          final night when night.entry.measure == SleepMeasure.inBed =>
            context.l10n.sleepMeasureInBed,
          _ when sleepGoal != null => context.l10n.goalValue(
            goal: formatDuration(context.l10n, sleepGoal),
          ),
          final night when night.isTypedIn => context.l10n.sourceManual,
          final night =>
            night.entry.sourceName.isEmpty
                ? store.healthSourceName
                : night.entry.sourceName,
        },
      ),
    );
  }

  Segment _bathSegment(BuildContext context, TodayViewModel today) {
    final baths = today.baths;
    final bath = baths.lastOrNull;
    return Segment(
      onTap: () => pushPage(context, BathScreen(day: today.day)),
      child: SegmentStat(
        label: context.l10n.recordBath,
        color: AppColors.wellness,
        mark: (tint) => Icon(Icons.bathtub_outlined, size: 16, color: tint),
        placeholder: context.l10n.noEntriesShort,
        value: bath == null ? null : formatTimeOfDay(bath.bathedAt),
        unit: bath == null
            ? null
            : [
                ?bath.water?.labelIn(context.l10n),
                ?bath.kind?.labelIn(context.l10n),
              ].join(' · '),
        caption: baths.length > 1
            ? context.l10n.timesCount(count: baths.length)
            : null,
      ),
    );
  }

  Segment _waterSegment(
    BuildContext context,
    AppStore store,
    TodayViewModel today,
  ) {
    final water = today.water;
    final reference = today.waterReferenceMl;
    return Segment(
      onTap: () => pushPage(context, WaterScreen(day: today.day)),
      // Up to the reference and no further: past it the water stays full
      // rather than rewarding more; none without a reference or a glass.
      background: switch (reference) {
        final reference? when reference > 0 && water.times > 0 => LevelFill(
          level: water.millilitres / reference,
          color: AppColors.water,
          motion: store.motion.acceleration,
        ),
        _ => null,
      },
      child: SegmentStat(
        label: context.l10n.healthDataWater,
        color: AppColors.water,
        mark: (tint) => Icon(Icons.water_drop_outlined, size: 16, color: tint),
        placeholder: context.l10n.noEntriesShort,
        value: water.times == 0 ? null : formatKcal(water.millilitres),
        unit: switch (reference) {
          final reference? => '/ ${formatKcal(reference)} mL',
          null => 'mL',
        },
        caption: water.times == 0
            ? null
            : context.l10n.timesCount(count: water.times),
      ),
    );
  }

  /// The day's movement, when the health platform counted any.
  Widget? _activity(BuildContext context, TodayViewModel today) {
    final totals = today.activityTotals;
    final lead = ActivityMetric.headline.where(totals.containsKey).firstOrNull;
    if (lead == null) return null;
    return Gutter(
      child: TodayActivityCard(
        lead: lead,
        totals: totals,
        hours: today.activityHours(lead) ?? List.filled(24, 0),
        onTap: () => pushPage(context, DailyActivityScreen(day: today.day)),
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
        child: CategoryGroup(
          label: TodaySection.week.labelIn(context.l10n),
          color: AppColors.training,
          tag: Text(
            target == null
                ? context.l10n.daysCount(count: active)
                : context.l10n.daysFraction(active: active, target: target),
            style: AppTextStyles.caption,
          ),
          children: [
            WeekStrip(
              days: days,
              today: DateTime(now.year, now.month, now.day),
              onTap: () => pushPage(context, const GoalScreen()),
            ),
          ],
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
        child: CategoryGroup(
          label: TodaySection.records.labelIn(
            context.l10n,
            isToday: today.isToday,
          ),
          color: AppColors.textSecondary,
          tag: all.length > shown
              ? LinkText(
                  label: context.l10n.allCount(count: all.length),
                  onTap: () =>
                      AppStoreScope.read(context).selectTab(HomeTab.log),
                )
              : null,
          children: [
            SegmentedGroup(
              rows: [
                for (final entry in records)
                  [
                    Segment(
                      onTap: switch (timelineDestination(
                        entry,
                        isSleep: today.isSleep,
                        mealById: today.backend.nutrition.mealById,
                        mealGroup: today.backend.nutrition.mealGroup,
                      )) {
                        final page? => () => pushPage(context, page),
                        null => null,
                      },
                      child: SegmentRow(
                        leading: AccentBar(
                          color: entry.category.color,
                          height: 28,
                        ),
                        title: entry.title,
                        caption: [
                          entry.timeLabel,
                          if (entry.detail.isNotEmpty) entry.detail,
                        ].join(' · '),
                      ),
                    ),
                  ],
              ],
            ),
          ],
        ),
      ),
    ];
  }
}

Segment _weightSegment(
  BuildContext context,
  ({
    BodyWeight? latest,
    List<(DateTime, double, double)> week,
    double? weekChange,
  })
  weight,
) {
  final (:latest, :week, :weekChange) = weight;
  return Segment(
    onTap: () => pushPage(context, const BodyScreen()),
    child: SegmentStat(
      label: context.l10n.moduleWeight,
      color: AppColors.body,
      mark: (tint) =>
          Icon(Icons.monitor_weight_outlined, size: 16, color: tint),
      placeholder: context.l10n.noEntriesShort,
      value: latest == null ? null : formatWeight(latest.weightKg),
      unit: 'kg',
      // The week sways when the device is shaken, held at its left edge,
      // and is drawn in from there as a chart is.
      chart: week.length < 2
          ? null
          : ShakeShear(
              motion: AppStoreScope.of(context).motion.acceleration,
              child: ChartEntrance(
                shows: week,
                builder: (context, drawn) => ClipRect(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: easedProgress(drawn),
                    child: WeightTrendChart(points: week, height: 28),
                  ),
                ),
              ),
            ),
      caption: switch ((latest, weekChange)) {
        (null, _) => null,
        (_, final change?) => context.l10n.weightChange7Days(
          change:
              '${change < 0 ? '−' : '+'}${formatWeight((change.abs() * 10).round() / 10)}',
        ),
        _ => context.dates.compactMonthDay(latest!.measuredAt),
      },
    ),
  );
}
