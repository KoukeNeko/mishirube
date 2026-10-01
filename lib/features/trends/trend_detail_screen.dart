import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../app/view_model.dart';
import '../../backend/application/goal_service.dart';
import '../../backend/application/insights_service.dart';
import '../../backend/engines/period_stats.dart';
import '../../backend/engines/trend_gist.dart';
import '../../domain/domain.dart';
import '../../backend/engines/trend_detail.dart';
import '../../backend/engines/trend_findings.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../activity/daily_activity_screen.dart';
import '../exercise/exercise_detail_screen.dart';
import '../body/body_screen.dart';
import '../nutrition/daily_nutrition_screen.dart';
import '../sleep/sleep_history.dart';
import '../sleep/sleep_regularity_card.dart';
import '../sleep/sleep_screen.dart';
import '../sleep/sleep_shortfall_screen.dart';
import '../sleep/sleep_view_model.dart';
import 'training_trends_screen.dart';
import 'trends_view_model.dart';
import '../../l10n/l10n.dart';

/// Tall enough to read a week's rise or fall at a glance.
const _mainChartHeight = 180.0;

/// How far back the page reads. A week and a month read sleep night by
/// night; the others read any area week by week.
enum _Range {
  week(1, nights: 7),
  month(4, nights: 30),
  quarter(13),
  half(26),
  year(52),
  all(null);

  const _Range(this.weeks, {this.nights});

  final int? weeks;

  /// The nights a night-by-night range reads; null for a weekly one.
  final int? nights;

  String labelIn(AppLocalizations l10n) => switch (this) {
    week => l10n.chartRangeWeek,
    month => l10n.chartRangeMonth,
    quarter => l10n.monthsCount(count: 3),
    half => l10n.monthsCount(count: 6),
    year => l10n.yearsCount(count: 1),
    all => l10n.logFilterAll,
  };
}

Color trendColor(TrendDomain domain) => switch (domain) {
  TrendDomain.body => AppColors.body,
  TrendDomain.training => AppColors.training,
  TrendDomain.sleep => AppColors.wellness,
  TrendDomain.nutrition => AppColors.nutrition,
  TrendDomain.activity => AppColors.activity,
};

/// The page where an area's records are looked up day by day.
Widget areaPageFor(TrendDomain domain) => switch (domain) {
  TrendDomain.body => const BodyScreen(),
  TrendDomain.training => const TrainingTrendsScreen(),
  TrendDomain.sleep => const SleepScreen(),
  TrendDomain.nutrition => const DailyNutritionScreen(),
  TrendDomain.activity => const DailyActivityScreen(),
};

/// One area over months (see `research/56-trends-insights.md`): where
/// the latest stretch sits against the baseline and against what is
/// normal for this person, week by week; what it is paired with; how
/// the days of the week differ; and what the other areas did over the
/// same weeks. Sleep also reads a week or a month night by night, and
/// keeps its regularity, overnight readings and what goes with shorter
/// nights here, so the sleep page holds only its day; the sleep owed
/// shows on both. The day-by-day
/// records are one tap further.
class TrendDetailScreen extends StatefulWidget {
  const TrendDetailScreen({super.key, required this.domain});

  final TrendDomain domain;

  @override
  State<TrendDetailScreen> createState() => _TrendDetailScreenState();
}

class _TrendDetailScreenState extends State<TrendDetailScreen> {
  // Steps are set against the year, so a year is what shows both.
  late _Range _range = widget.domain == TrendDomain.activity
      ? _Range.year
      : _Range.half;

  /// The nights up to today, for sleep's own sections; made only for
  /// sleep.
  SleepViewModel? _sleep;

  SleepViewModel get _sleepModel =>
      _sleep ??= SleepViewModel(AppStoreScope.read(context).backend);

  @override
  void dispose() {
    _sleep?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      create: TrendsViewModel.new,
      builder: (context, model) {
        final domain = widget.domain;
        final isSleep = domain == TrendDomain.sleep;
        final trend = model.areaTrend(domain, weeks: _range.weeks);
        final others = [
          for (final line in model.report.lines)
            if (line.domain != domain) line,
        ];
        final nightly = isSleep ? _range.nights : null;
        return DetailPage(
          appBar: PageAppBar(
            title: context.l10n.areaTrend(area: domain.labelIn(context.l10n)),
          ),
          children: [
            Gutter(
              child: SegmentedChoice<_Range>(
                options: [
                  for (final range in _Range.values)
                    if (isSleep || range.nights == null) range,
                ],
                selected: _range,
                labelOf: (range) => range.labelIn(context.l10n),
                selectedColor: trendColor(domain),
                onChanged: (range) => setState(() => _range = range),
              ),
            ),
            if (nightly != null) ...[
              ...sleepNightItems(context, _sleepModel, nightly),
              ..._statistics(
                context,
                model,
                trend,
                days: [
                  for (final night in _sleepModel.nightsAsleep(nightly))
                    (night.sleptAt, night.duration.inMinutes.toDouble()),
                ],
              ),
            ] else ...[
              Gutter(child: _Overview(trend: trend)),
              if (domain == TrendDomain.training)
                if (model.weeklyGoal case final goal?)
                  Gutter(
                    child: _GoalWeeks(
                      goal: goal,
                      weeks: _range.weeks ?? goal.weeks.length,
                    ),
                  ),
              if (trend.secondary case final secondary?)
                Gutter(
                  child: _SecondaryCard(domain: domain, detail: secondary),
                ),
              if (trend.schedule case final schedule?
                  when schedule.any((week) => week != null))
                Gutter(
                  child: _SleepSchedule(
                    weekStarts: trend.detail.weekStarts,
                    schedule: schedule,
                    targets: targetsOf(_sleepModel),
                  ),
                ),
              if (isSleep && trend.days.isNotEmpty)
                if (model.sleepGoal case final goal?)
                  Gutter(
                    child: _SleepGoalWeeks(trend: trend, goal: goal),
                  ),
              ..._statistics(context, model, trend),
              if (trend.detail.weekdays.any((value) => value != null)) ...[
                Gutter(child: SectionLabel(context.l10n.weekdaySection)),
                Gutter(child: _Weekdays(trend: trend)),
              ],
            ],
            if (isSleep) ...[
              // A fixed fortnight, whatever the range, as on the sleep
              // page.
              if (_sleepModel.shortfall(shortfallDays).recorded > 0) ...[
                Gutter(child: SectionLabel(context.l10n.sleepDebtSection)),
                Gutter(
                  child: SleepShortfallCard(
                    model: _sleepModel,
                    onTap: () => pushPage(
                      context,
                      SleepShortfallScreen(day: _sleepModel.day),
                    ),
                  ),
                ),
              ],
              // A fixed four weeks, whatever the range.
              if (_sleepModel.nightsAsleep(2 * regularityWindowDays)
                  case final nights
                  when nights.any((night) => night.startedAt != null)) ...[
                Gutter(
                  child: SectionLabel(context.l10n.sleepRegularitySection),
                ),
                Gutter(
                  child: SleepRegularityCard(
                    nights: nights,
                    day: _sleepModel.day,
                    targets: targetsOf(_sleepModel),
                  ),
                ),
              ],
              ...sleepStageItems(
                context,
                _sleepModel,
                nightly ??
                    trend.detail.weekStarts.length * DateTime.daysPerWeek,
              ),
              ...sleepVitalItems(
                context,
                _sleepModel,
                nightly ??
                    trend.detail.weekStarts.length * DateTime.daysPerWeek,
              ),
              ...sleepFactorItems(context, _sleepModel),
            ],
            if (others.isNotEmpty) ...[
              Gutter(child: SectionLabel(context.l10n.otherAreasSection)),
              Gutter(
                child: GroupedCard(
                  children: [
                    for (final line in others)
                      NavRow(
                        leading: AccentBar(
                          color: trendColor(line.domain),
                          height: 28,
                        ),
                        title: line.domain.labelIn(context.l10n),
                        subtitle: line.value,
                        detail: line.change,
                        onTap: () => pushPage(
                          context,
                          TrendDetailScreen(domain: line.domain),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            Gutter(
              child: NavCard(
                title: context.l10n.dailyEntries,
                onTap: () => pushPage(context, areaPageFor(domain)),
              ),
            ),
          ],
        );
      },
    );
  }
}

double _tenth(double value) => (value * 10).round() / 10;

/// An area's weekly value as the page writes it.
String _valueOf(
  AppLocalizations l10n,
  TrendDomain domain,
  double value,
) => switch (domain) {
  TrendDomain.body => '${formatWeight(_tenth(value))} kg',
  TrendDomain.training => l10n.perWeekTimes(count: value.toStringAsFixed(1)),
  TrendDomain.sleep => formatDuration(l10n, Duration(minutes: value.round())),
  TrendDomain.nutrition => '${formatKcal(value.round())} kcal',
  TrendDomain.activity => l10n.stepsValue(steps: formatKcal(value.round())),
};

/// `+22 分`, `−0.4 kg`: how far one level sits from another.
String _differenceOf(AppLocalizations l10n, TrendDomain domain, double delta) {
  final sign = delta < 0 ? '−' : '+';
  final size = delta.abs();
  return '$sign${switch (domain) {
    TrendDomain.body => '${formatWeight(_tenth(size))} kg',
    TrendDomain.training => l10n.timesValue(count: size.toStringAsFixed(1)),
    TrendDomain.sleep => l10n.durationMinutes(minutes: size.round()),
    // A summary's figure is rounded to what a reader holds in mind.
    TrendDomain.nutrition => '${formatKcal(_roundTo(size, 10))} kcal',
    TrendDomain.activity => l10n.stepsValue(steps: formatKcal(_roundTo(size, 100))),
  }}';
}

int _roundTo(double value, int step) => (value / step).round() * step;

/// The latest stretch in a few words and one figure (see
/// `research/78-plain-summaries.md`): against the usual range, by how
/// much against the weeks before; null with nothing to say.
String? gistTextOf(AppLocalizations l10n, AreaTrend trend) {
  final domain = trend.domain;
  if (domain == TrendDomain.body) {
    final gist = trend.weightGist;
    if (gist == null) return null;
    return switch (gist.position) {
      GistPosition.usual => l10n.gistSteady,
      GistPosition.above =>
        '${l10n.gistRising} · ${_differenceOf(l10n, domain, gist.change)}',
      GistPosition.below =>
        '${l10n.gistFalling} · ${_differenceOf(l10n, domain, gist.change)}',
    };
  }
  final gist = trend.gist;
  if (gist == null) return null;
  if (!gist.isEnough) {
    return '${l10n.gistNotEnough} · '
        '${l10n.coverageDays(count: gist.covered, total: gist.span)}';
  }
  final word = switch (gist.position) {
    GistPosition.usual => l10n.gistUsual,
    GistPosition.above => l10n.gistMore,
    GistPosition.below => l10n.gistLess,
    null => null,
  };
  if (word == null) return null;
  final difference = gist.difference;
  if (gist.position == GistPosition.usual || difference == null) return word;
  final change = _differenceOf(l10n, domain, difference);
  return '$word · ${switch (domain) {
    TrendDomain.sleep => l10n.perNightChange(change: change),
    TrendDomain.training => l10n.perWeekChange(change: change),
    _ => l10n.perDayChange(change: change),
  }}';
}

/// `9月14日 起`: the week a point stands for.
String _weekOf(BuildContext context, DateTime start) =>
    context.l10n.weekFrom(date: context.dates.compactMonthDay(start));

/// The latest stretch against the baseline, the weeks behind them, and
/// how many days the latest weeks have records for.
class _Overview extends StatelessWidget {
  const _Overview({required this.trend});

  final AreaTrend trend;

  @override
  Widget build(BuildContext context) {
    final domain = trend.domain;
    final detail = trend.detail;
    final color = trendColor(domain);
    final isYearly = domain == TrendDomain.activity;
    final l10n = context.l10n;
    final recentLabel = isYearly ? l10n.last13Weeks : l10n.last4Weeks;
    final baselineLabel = isYearly ? l10n.pastYear : l10n.prior12Weeks;
    final recent = detail.recent;
    final baseline = detail.baseline;
    final recentDays = detail.daysWithRecords.reversed.take(4).toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryLabel(
            label: l10n.periodAverage(period: recentLabel),
            color: color,
          ),
          if (gistTextOf(l10n, trend) case final gist?) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(gist, style: AppTextStyles.itemTitle),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            recent == null ? '—' : _valueOf(l10n, domain, recent.value),
            style: AppTextStyles.bigNumber,
          ),
          if ((recent, baseline) case (final recent?, final baseline?))
            Text(
              '$baselineLabel ${_valueOf(l10n, domain, baseline.value)} · '
              '${_differenceOf(l10n, domain, recent.value - baseline.value)}',
              style: AppTextStyles.caption,
            ),
          const SizedBox(height: AppSpacing.md),
          if (detail.values.nonNulls.isEmpty)
            Text(l10n.noEntriesShort, style: AppTextStyles.caption)
          else
            ChartScrubber(
              count: detail.values.length,
              indexAt: ChartScrubber.points(detail.values.length),
              idle: domain == TrendDomain.training
                  ? l10n.weeklyCount
                  : l10n.weeklyAverage,
              readoutOf: (index) => switch (detail.values[index]) {
                final value? =>
                  '${_weekOf(context, detail.weekStarts[index])} · '
                      '${_valueOf(l10n, domain, value)}',
                null =>
                  '${_weekOf(context, detail.weekStarts[index])} · '
                      '${l10n.noEntriesShort}',
              },
              builder: (context, selected) => Sparkline(
                values: detail.values,
                color: color,
                height: _mainChartHeight,
                normal: detail.normal,
                levels: [
                  if (baseline != null)
                    ChartLevel(
                      value: baseline.value,
                      from: baseline.fromWeek,
                      to: baseline.toWeek,
                      color: AppColors.textSecondary,
                    ),
                  if (recent != null)
                    ChartLevel(
                      value: recent.value,
                      from: recent.fromWeek,
                      to: recent.toWeek,
                      color: color,
                    ),
                ],
                selected: selected,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xxs,
            children: [
              if (detail.normal != null)
                ChartKey(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  label: l10n.usualRange,
                ),
              if (baseline != null)
                ChartKey(color: AppColors.textSecondary, label: baselineLabel),
              if (recent != null) ChartKey(color: color, label: recentLabel),
            ],
          ),
          if (domain != TrendDomain.training && recentDays.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.daysLoggedPerWeek(
                days: (recentDays.reduce((a, b) => a + b) / recentDays.length)
                    .toStringAsFixed(1),
              ),
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }
}

/// What the area's figure is paired with, week by week.
class _SecondaryCard extends StatelessWidget {
  const _SecondaryCard({required this.domain, required this.detail});

  final TrendDomain domain;
  final TrendDetail detail;

  String _label(AppLocalizations l10n) => switch (domain) {
    TrendDomain.body => l10n.scaleWeight,
    TrendDomain.training => l10n.weeklyVolume,
    TrendDomain.sleep => '',
    TrendDomain.nutrition => l10n.macroProtein,
    TrendDomain.activity => l10n.restingHeartRate,
  };

  String _value(AppLocalizations l10n, double value) => switch (domain) {
    TrendDomain.body => '${formatWeight(_tenth(value))} kg',
    TrendDomain.training => '${formatKcal(value.round())} kg',
    TrendDomain.sleep => '',
    TrendDomain.nutrition => '${value.round()} g',
    TrendDomain.activity => '${value.round()} ${l10n.unitBpm}',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = trendColor(domain);
    final latest = detail.values.nonNulls.lastOrNull;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_label(l10n), style: AppTextStyles.itemTitle),
              ),
              if (latest != null)
                Text(_value(l10n, latest), style: AppTextStyles.body),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (latest == null)
            Text(l10n.noEntriesShort, style: AppTextStyles.caption)
          else
            ChartScrubber(
              count: detail.values.length,
              indexAt: ChartScrubber.points(detail.values.length),
              idle: domain == TrendDomain.training
                  ? l10n.weeklyTotal
                  : l10n.weeklyAverage,
              readoutOf: (index) => switch (detail.values[index]) {
                final value? =>
                  '${_weekOf(context, detail.weekStarts[index])} · '
                      '${_value(l10n, value)}',
                null =>
                  '${_weekOf(context, detail.weekStarts[index])} · '
                      '${l10n.noEntriesShort}',
              },
              builder: (context, selected) => Sparkline(
                values: detail.values,
                color: color,
                height: 100,
                selected: selected,
              ),
            ),
        ],
      ),
    );
  }
}

/// Each weekday's average (or how often it comes round), Monday first.
class _Weekdays extends StatelessWidget {
  const _Weekdays({required this.trend});

  final AreaTrend trend;

  @override
  Widget build(BuildContext context) {
    final domain = trend.domain;
    final values = trend.detail.weekdays;
    final known = [
      for (final (index, value) in values.indexed)
        if (value != null) (index, value),
    ];
    final highest = known.reduce((a, b) => b.$2 > a.$2 ? b : a);
    final lowest = known.reduce((a, b) => b.$2 < a.$2 ? b : a);
    final color = trendColor(domain);
    // Weight moves little day to day; its bars start from the lightest
    // day so the differences show.
    final floor = domain == TrendDomain.body ? lowest.$2 * 0.99 : 0.0;
    String dayValue(int index, double? value) =>
        '${context.dates.weekdayNumberName(index + 1)} '
        '${value == null ? context.l10n.noEntriesShort : _valueOf(context.l10n, domain, value)}';
    // Reading a day says its figure; at rest the highest and lowest.
    return AppCard(
      child: ChartScrubber(
        count: values.length,
        indexAt: ChartScrubber.slots(values.length),
        idle: context.l10n.highestLowest(
          high: dayValue(highest.$1, highest.$2),
          low: dayValue(lowest.$1, lowest.$2),
        ),
        readoutOf: (index) => dayValue(index, values[index]),
        builder: (context, selected) => MiniBarChart(
          bars: [
            for (final (index, value) in values.indexed)
              (
                context.dates.weekdayNumber(index + 1),
                value == null ? null : ((value - floor) * 100).round(),
              ),
          ],
          height: 80,
          color: color,
          dimColor: color.withValues(alpha: 0.4),
          selected: selected ?? highest.$1,
          // Weekdays, not periods: none of them is still going.
          highlightsLast: false,
        ),
      ),
    );
  }
}

/// The figures the span comes to, then how its days spread (or, for
/// food, how the energy splits between the macros).
List<Widget> _statistics(
  BuildContext context,
  TrendsViewModel model,
  AreaTrend trend, {
  List<(DateTime, double)>? days,
}) {
  final l10n = context.l10n;
  final domain = trend.domain;
  final color = trendColor(domain);
  // A night-by-night range reads its own nights, not the weeks'.
  final daily = days ?? trend.days;
  final stats = model.statsOf(daily);
  final figures = switch (domain) {
    TrendDomain.training => _trainingFigures(context, trend, model.weeklyGoal),
    _ when stats == null => const <Figure>[],
    TrendDomain.body => _bodyFigures(context, trend, stats),
    TrendDomain.sleep => _sleepFigures(context, daily, stats, model.sleepGoal),
    TrendDomain.nutrition => _nutritionFigures(context, trend, stats),
    TrendDomain.activity => _activityFigures(context, stats),
  };
  final values = [for (final (_, value) in daily) value];
  final spread = switch (domain) {
    TrendDomain.sleep => (
      edges: const [360.0, 420.0, 480.0, 540.0],
      labels: const ['<6', '6–7', '7–8', '8–9', '9+'],
      unit: l10n.hoursUnit,
      countLabel: (int count) => l10n.nightsCount(count: count),
    ),
    TrendDomain.activity => (
      edges: const [2500.0, 5000.0, 7500.0, 10000.0],
      labels: const ['<2.5k', '2.5–5k', '5–7.5k', '7.5–10k', '10k+'],
      unit: l10n.stepsUnit,
      countLabel: (int count) => l10n.daysCount(count: count),
    ),
    _ => null,
  };
  return [
    if (figures.isNotEmpty) ...[
      Gutter(child: SectionLabel(l10n.statsSection)),
      Gutter(child: FigureGrid(figures: figures)),
    ],
    // A week of days at least, or the spread is a handful of points.
    if (spread != null && values.length >= DateTime.daysPerWeek) ...[
      Gutter(child: SectionLabel(l10n.distributionSection)),
      Gutter(
        child: AppCard(
          child: DistributionChart(
            labels: spread.labels,
            counts: bucketCounts(values, spread.edges),
            unit: spread.unit,
            color: color,
            idle: spread.countLabel(values.length),
            countLabel: spread.countLabel,
          ),
        ),
      ),
    ],
    if (trend.macros case final macros?) ...[
      Gutter(child: SectionLabel(l10n.macroSplit)),
      Gutter(child: _MacroSplit(macros: macros)),
    ],
    if (trend.topExercises.isNotEmpty) ...[
      Gutter(child: SectionLabel(l10n.exercisesLabel)),
      Gutter(
        child: GroupedCard(
          children: [
            for (final (exercise, sets) in trend.topExercises)
              NavRow(
                title: exercise.name,
                trailing: Text(
                  l10n.setsCount(count: sets),
                  style: AppTextStyles.body,
                ),
                onTap: () =>
                    pushPage(context, ExerciseDetailScreen(exercise: exercise)),
              ),
          ],
        ),
      ),
    ],
  ];
}

/// `最高 · 9/14`: a figure's name and the day it fell on.
String _onDay(BuildContext context, String label, DateTime day) =>
    '$label · ${context.dates.compactMonthDay(day)}';

List<Figure> _bodyFigures(
  BuildContext context,
  AreaTrend trend,
  PeriodStats stats,
) {
  final l10n = context.l10n;
  String kg(double value) => formatWeight(_tenth(value));
  final weeks = trend.detail.values;
  final first = weeks.indexWhere((value) => value != null);
  final last = weeks.lastIndexWhere((value) => value != null);
  final change = first < 0 || last <= first
      ? null
      : weeks[last]! - weeks[first]!;
  return [
    if (change != null) ...[
      (
        label: l10n.periodChange,
        value: _differenceOf(l10n, TrendDomain.body, change),
        unit: null,
        color: null,
      ),
      (
        label: l10n.changePerWeek,
        value: _differenceOf(l10n, TrendDomain.body, change / (last - first)),
        unit: null,
        color: null,
      ),
    ],
    (
      label: _onDay(context, l10n.statHighest, stats.highest.$1),
      value: kg(stats.highest.$2),
      unit: 'kg',
      color: null,
    ),
    (
      label: _onDay(context, l10n.statLowest, stats.lowest.$1),
      value: kg(stats.lowest.$2),
      unit: 'kg',
      color: null,
    ),
    (
      label: l10n.measurementsCount,
      value: l10n.timesValue(count: '${stats.count}'),
      unit: null,
      color: null,
    ),
  ];
}

List<Figure> _sleepFigures(
  BuildContext context,
  List<(DateTime, double)> nights,
  PeriodStats stats,
  Duration? goal,
) {
  final l10n = context.l10n;
  String length(double minutes) =>
      formatDuration(context.l10n, Duration(minutes: minutes.round()));
  final met = goal == null
      ? null
      : nights.where((night) => night.$2 >= goal.inMinutes).length;
  return [
    (
      label: l10n.averageTimeAsleep,
      value: length(stats.mean),
      unit: null,
      color: null,
    ),
    (
      label: l10n.halfNightsOver,
      value: length(stats.median),
      unit: null,
      color: null,
    ),
    (
      label: _onDay(context, l10n.statLongest, stats.highest.$1),
      value: length(stats.highest.$2),
      unit: null,
      color: null,
    ),
    (
      label: _onDay(context, l10n.statShortest, stats.lowest.$1),
      value: length(stats.lowest.$2),
      unit: null,
      color: null,
    ),
    (
      label: l10n.nightsRecorded,
      value: l10n.nightsCount(count: stats.count),
      unit: null,
      color: null,
    ),
    if (met != null)
      (
        label: l10n.sleepGoalMetLabel,
        value: l10n.nightsOutOf(count: met, total: stats.count),
        unit: null,
        color: null,
      ),
  ];
}

List<Figure> _nutritionFigures(
  BuildContext context,
  AreaTrend trend,
  PeriodStats stats,
) {
  final l10n = context.l10n;
  String kcal(double value) => formatKcal(value.round());
  return [
    (
      label: l10n.dailyAverage,
      value: kcal(stats.mean),
      unit: 'kcal',
      color: null,
    ),
    (
      label: l10n.halfDaysOver,
      value: kcal(stats.median),
      unit: 'kcal',
      color: null,
    ),
    (
      label: _onDay(context, l10n.statHighest, stats.highest.$1),
      value: kcal(stats.highest.$2),
      unit: 'kcal',
      color: null,
    ),
    (
      label: _onDay(context, l10n.statLowest, stats.lowest.$1),
      value: kcal(stats.lowest.$2),
      unit: 'kcal',
      color: null,
    ),
    (
      label: l10n.daysRecorded,
      value: switch (trend.loggedDays) {
        final logged? => l10n.completeOutOf(count: stats.count, total: logged),
        null => l10n.daysCount(count: stats.count),
      },
      unit: null,
      color: null,
    ),
    if (trend.macros case final macros?)
      (
        label: l10n.averageStage(stage: l10n.macroProtein),
        value: '${macros.protein.round()}',
        unit: 'g',
        color: AppColors.macroProtein,
      ),
  ];
}

List<Figure> _activityFigures(BuildContext context, PeriodStats stats) {
  final l10n = context.l10n;
  String steps(double value) => formatKcal(value.round());
  return [
    (
      label: l10n.dailyAverage,
      value: steps(stats.mean),
      unit: l10n.stepsUnit,
      color: null,
    ),
    (
      label: l10n.halfDaysOver,
      value: steps(stats.median),
      unit: l10n.stepsUnit,
      color: null,
    ),
    (
      label: _onDay(context, l10n.statHighest, stats.highest.$1),
      value: steps(stats.highest.$2),
      unit: l10n.stepsUnit,
      color: null,
    ),
    (
      label: _onDay(context, l10n.statLowest, stats.lowest.$1),
      value: steps(stats.lowest.$2),
      unit: l10n.stepsUnit,
      color: null,
    ),
    (
      label: l10n.daysRecorded,
      value: l10n.daysCount(count: stats.count),
      unit: null,
      color: null,
    ),
  ];
}

List<Figure> _trainingFigures(
  BuildContext context,
  AreaTrend trend,
  GoalOverview? goal,
) {
  final l10n = context.l10n;
  final weeks = trend.detail.values.nonNulls.toList();
  if (weeks.isEmpty) return const [];
  final workouts = weeks.fold(0.0, (sum, value) => sum + value).round();
  final volume = trend.secondary?.values.nonNulls.fold(
    0.0,
    (sum, value) => sum + value,
  );
  final judged = goal == null
      ? const <WeekProgress>[]
      : [
          for (final week in goal.weeks.reversed.take(weeks.length))
            if (!week.isCurrent && !week.isPaused) week,
        ];
  return [
    (
      label: l10n.workoutsTotal,
      value: l10n.timesValue(count: '$workouts'),
      unit: null,
      color: null,
    ),
    (
      label: l10n.weeklyAverage,
      value: l10n.timesValue(
        count: (workouts / weeks.length).toStringAsFixed(1),
      ),
      unit: null,
      color: null,
    ),
    if (volume != null && volume > 0)
      (
        label: l10n.totalVolume,
        value: formatKcal(volume.round()),
        unit: 'kg',
        color: null,
      ),
    if (judged.isNotEmpty)
      (
        label: l10n.weeklyGoalMetLabel,
        value: l10n.weeksOutOf(
          count: judged.where((week) => week.isMet).length,
          total: judged.length,
        ),
        unit: null,
        color: null,
      ),
  ];
}

/// Energy on an average complete day, split between protein,
/// carbohydrate and fat by the energy each carries.
class _MacroSplit extends StatelessWidget {
  const _MacroSplit({required this.macros});

  final ({double protein, double carb, double fat}) macros;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final parts = [
      (l10n.macroProtein, macros.protein, 4.0, AppColors.macroProtein),
      (l10n.macroCarb, macros.carb, 4.0, AppColors.macroCarb),
      (l10n.macroFat, macros.fat, 9.0, AppColors.macroFat),
    ];
    final energy = parts.fold(0.0, (sum, part) => sum + part.$2 * part.$3);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentBar(
            segments: [
              for (final (_, grams, perGram, color) in parts)
                (grams * perGram, color),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xxs,
            children: [
              for (final (name, grams, perGram, color) in parts)
                ChartKey(
                  color: color,
                  label:
                      '$name ${grams.round()} g · '
                      '${energy <= 0 ? 0 : (grams * perGram / energy * 100).round()}%',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The weekly goal week by week: days active each week against the goal,
/// with a check on each week that met it.
class _GoalWeeks extends StatelessWidget {
  const _GoalWeeks({required this.goal, required this.weeks});

  final GoalOverview goal;
  final int weeks;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shown = goal.weeks.reversed.take(weeks).toList().reversed.toList();
    final target = shown.last.targetDays;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryLabel(label: l10n.weeklyGoal, color: AppColors.training),
          const SizedBox(height: AppSpacing.sm),
          GoalWeeksChart(
            values: [for (final week in shown) week.activeDays],
            goal: target,
            met: {
              for (final (index, week) in shown.indexed)
                if (week.isMet) index,
            },
            color: AppColors.training,
            idle: l10n.goalValue(goal: l10n.daysCount(count: target)),
            readoutOf: (index) {
              final week = shown[index];
              return [
                _weekOf(context, week.start),
                '${week.activeDays} / ${l10n.daysCount(count: week.targetDays)}',
                if (week.isMet) l10n.goalReached,
              ].join(' · ');
            },
          ),
        ],
      ),
    );
  }
}

/// `23:42`: minutes after noon as a time of day.
String _clockFromNoon(double minutes) =>
    formatMinutesOfDay(minutes.round() + 12 * 60);

/// Each week's average night from bedtime down to waking: whether nights
/// begin later, end later, or drift, which an average length hides.
class _SleepSchedule extends StatelessWidget {
  const _SleepSchedule({
    required this.weekStarts,
    required this.schedule,
    this.targets = const [],
  });

  final List<DateTime> weekStarts;
  final List<(double, double)?> schedule;

  /// The schedule the user aims for, minutes after midnight.
  final List<int> targets;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ends = context.dates.compactSpanEnds(
      weekStarts.first,
      weekStarts.last,
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryLabel(label: l10n.bedAndWake, color: AppColors.wellness),
          const SizedBox(height: AppSpacing.md),
          ChartScrubber(
            count: schedule.length,
            indexAt: ChartScrubber.slots(schedule.length),
            idle: l10n.weeklyAverage,
            readoutOf: (index) => [
              _weekOf(context, weekStarts[index]),
              switch (schedule[index]) {
                (final bedtime, final wake) =>
                  '${_clockFromNoon(bedtime)}–${_clockFromNoon(wake)}',
                null => l10n.noEntriesShort,
              },
            ].join(' · '),
            builder: (context, selected) => RangeBarChart(
              ranges: schedule,
              color: AppColors.wellness,
              labelOf: _clockFromNoon,
              start: ends.$1,
              end: ends.$2,
              selected: selected,
              downward: true,
              // On the chart's own clock, which starts at noon.
              levels: [
                for (final minutes in targets)
                  ((minutes - 12 * 60) % Duration.minutesPerDay).toDouble(),
              ],
            ),
          ),
          if (targets.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            targetKey(context),
          ],
        ],
      ),
    );
  }
}

/// How many nights each week met the sleep goal, out of the week's
/// seven: the goal as it is set now, held against every week.
class _SleepGoalWeeks extends StatelessWidget {
  const _SleepGoalWeeks({required this.trend, required this.goal});

  final AreaTrend trend;
  final Duration goal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final weekStarts = trend.detail.weekStarts;
    final nights = List.filled(weekStarts.length, 0);
    final met = List.filled(weekStarts.length, 0);
    for (final (at, minutes) in trend.days) {
      final day = DateTime(at.year, at.month, at.day);
      final week =
          day.difference(weekStarts.first).inDays ~/ DateTime.daysPerWeek;
      if (week < 0 || week >= weekStarts.length) continue;
      nights[week]++;
      if (minutes >= goal.inMinutes) met[week]++;
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryLabel(
            label: l10n.sleepGoalMetLabel,
            color: AppColors.wellness,
          ),
          const SizedBox(height: AppSpacing.md),
          ChartScrubber(
            count: weekStarts.length,
            indexAt: ChartScrubber.slots(weekStarts.length),
            idle: l10n.goalValue(goal: formatDuration(context.l10n, goal)),
            readoutOf: (index) => [
              _weekOf(context, weekStarts[index]),
              if (nights[index] == 0)
                l10n.noEntriesShort
              else
                l10n.nightsOutOf(count: met[index], total: nights[index]),
            ].join(' · '),
            builder: (context, selected) => MiniBarChart(
              bars: [
                for (final (index, count) in met.indexed)
                  ('', nights[index] == 0 ? null : count),
              ],
              height: 80,
              showLabels: false,
              color: AppColors.wellness,
              dimColor: AppColors.wellness.withValues(alpha: 0.45),
              selected: selected,
              top: DateTime.daysPerWeek,
            ),
          ),
        ],
      ),
    );
  }
}
