import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../app/view_model.dart';
import '../../backend/application/insights_service.dart';
import '../../backend/engines/trend_detail.dart';
import '../../backend/engines/trend_findings.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../activity/daily_activity_screen.dart';
import '../body/body_screen.dart';
import '../nutrition/daily_nutrition_screen.dart';
import '../sleep/sleep_screen.dart';
import 'training_trends_screen.dart';
import 'trends_view_model.dart';
import '../../l10n/l10n.dart';

/// Tall enough to read a week's rise or fall at a glance.
const _mainChartHeight = 180.0;

/// How far back the page reads.
enum _Range {
  quarter(13),
  half(26),
  year(52),
  all(null);

  const _Range(this.weeks);

  final int? weeks;

  String labelIn(AppLocalizations l10n) => switch (this) {
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
/// same weeks. The day-by-day records are one tap further.
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

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      create: TrendsViewModel.new,
      builder: (context, model) {
        final domain = widget.domain;
        final trend = model.areaTrend(domain, weeks: _range.weeks);
        final others = [
          for (final line in model.report.lines)
            if (line.domain != domain) line,
        ];
        return DetailPage(
          appBar: PageAppBar(
            title: context.l10n.areaTrend(area: domain.labelIn(context.l10n)),
          ),
          children: [
            Gutter(
              child: SegmentedChoice<_Range>(
                options: _Range.values,
                selected: _range,
                labelOf: (range) => range.labelIn(context.l10n),
                selectedColor: trendColor(domain),
                onChanged: (range) => setState(() => _range = range),
              ),
            ),
            Gutter(child: _Overview(trend: trend)),
            if (trend.secondary case final secondary?)
              Gutter(
                child: _SecondaryCard(domain: domain, detail: secondary),
              ),
            if (trend.sleepTimes case final times?)
              Gutter(
                child: NavCard(
                  title: context.l10n.sleepTimesAverage(
                    bedtime: _clockOf(times.bedtime),
                    wake: _clockOf(times.wake),
                  ),
                  subtitle: context.l10n.last4WeeksAverage,
                  showChevron: false,
                ),
              ),
            if (trend.detail.weekdays.any((value) => value != null)) ...[
              Gutter(child: SectionLabel(context.l10n.weekdaySection)),
              Gutter(child: _Weekdays(trend: trend)),
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

/// `23:40`: minutes after midnight as a clock time.
String _clockOf(double minutes) {
  final total = minutes.round() % Duration.minutesPerDay;
  return '${(total ~/ 60).toString().padLeft(2, '0')}:'
      '${(total % 60).toString().padLeft(2, '0')}';
}

double _tenth(double value) => (value * 10).round() / 10;

/// An area's weekly value as the page writes it.
String _valueOf(AppLocalizations l10n, TrendDomain domain, double value) =>
    switch (domain) {
      TrendDomain.body => '${formatWeight(_tenth(value))} kg',
      TrendDomain.training => l10n.perWeekTimes(
        count: value.toStringAsFixed(1),
      ),
      TrendDomain.sleep => formatHoursMinutes(Duration(minutes: value.round())),
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
    TrendDomain.nutrition => '${formatKcal(size.round())} kcal',
    TrendDomain.activity => l10n.stepsValue(steps: formatKcal(size.round())),
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
                _Key(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  label: l10n.usualRange,
                ),
              if (baseline != null)
                _Key(color: AppColors.textSecondary, label: baselineLabel),
              if (recent != null) _Key(color: color, label: recentLabel),
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

/// A swatch and what it stands for.
class _Key extends StatelessWidget {
  const _Key({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(label, style: AppTextStyles.caption),
      ],
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MiniBarChart(
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
            selected: highest.$1,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.l10n.highestLowest(
              high:
                  '${context.dates.weekdayNumberName(highest.$1 + 1)} '
                  '${_valueOf(context.l10n, domain, highest.$2)}',
              low:
                  '${context.dates.weekdayNumberName(lowest.$1 + 1)} '
                  '${_valueOf(context.l10n, domain, lowest.$2)}',
            ),
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
