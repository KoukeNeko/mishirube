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

/// Tall enough to read a week's rise or fall at a glance.
const _mainChartHeight = 180.0;

/// How far back the page reads.
enum _Range {
  quarter('3 個月', 13),
  half('6 個月', 26),
  year('1 年', 52),
  all('全部', null);

  const _Range(this.label, this.weeks);

  final String label;
  final int? weeks;
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
          appBar: PageAppBar(title: '${domain.label}趨勢'),
          children: [
            Gutter(
              child: SegmentedChoice<_Range>(
                options: _Range.values,
                selected: _range,
                labelOf: (range) => range.label,
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
                  title:
                      '${_clockOf(times.bedtime)} 入睡 · '
                      '${_clockOf(times.wake)} 起床',
                  subtitle: '近 4 週平均',
                  showChevron: false,
                ),
              ),
            if (trend.detail.weekdays.any((value) => value != null)) ...[
              Gutter(child: const SectionLabel('星期')),
              Gutter(child: _Weekdays(trend: trend)),
            ],
            if (others.isNotEmpty) ...[
              Gutter(child: const SectionLabel('同期其他領域')),
              Gutter(
                child: GroupedCard(
                  children: [
                    for (final line in others)
                      NavRow(
                        leading: AccentBar(
                          color: trendColor(line.domain),
                          height: 28,
                        ),
                        title: line.domain.label,
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
                title: '每日紀錄',
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
String _valueOf(TrendDomain domain, double value) => switch (domain) {
  TrendDomain.body => '${formatWeight(_tenth(value))} kg',
  TrendDomain.training => '每週 ${value.toStringAsFixed(1)} 次',
  TrendDomain.sleep => formatHoursMinutes(Duration(minutes: value.round())),
  TrendDomain.nutrition => '${formatKcal(value.round())} kcal',
  TrendDomain.activity => '${formatKcal(value.round())} 步',
};

/// `+22 分`, `−0.4 kg`: how far one level sits from another.
String _differenceOf(TrendDomain domain, double delta) {
  final sign = delta < 0 ? '−' : '+';
  final size = delta.abs();
  return '$sign${switch (domain) {
    TrendDomain.body => '${formatWeight(_tenth(size))} kg',
    TrendDomain.training => '${size.toStringAsFixed(1)} 次',
    TrendDomain.sleep => '${size.round()} 分',
    TrendDomain.nutrition => '${formatKcal(size.round())} kcal',
    TrendDomain.activity => '${formatKcal(size.round())} 步',
  }}';
}

/// `9/14 起`: the week a point stands for.
String _weekOf(DateTime start) => '${start.month}/${start.day} 起';

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
    final recentLabel = isYearly ? '近 13 週' : '近 4 週';
    final baselineLabel = isYearly ? '過去一年' : '前 12 週';
    final recent = detail.recent;
    final baseline = detail.baseline;
    final recentDays = detail.daysWithRecords.reversed.take(4).toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryLabel(label: '$recentLabel平均', color: color),
          const SizedBox(height: AppSpacing.xs),
          Text(
            recent == null ? '—' : _valueOf(domain, recent.value),
            style: AppTextStyles.bigNumber,
          ),
          if ((recent, baseline) case (final recent?, final baseline?))
            Text(
              '$baselineLabel ${_valueOf(domain, baseline.value)} · '
              '${_differenceOf(domain, recent.value - baseline.value)}',
              style: AppTextStyles.caption,
            ),
          const SizedBox(height: AppSpacing.md),
          if (detail.values.nonNulls.isEmpty)
            const Text('沒有紀錄', style: AppTextStyles.caption)
          else
            ChartScrubber(
              count: detail.values.length,
              indexAt: ChartScrubber.points(detail.values.length),
              idle: domain == TrendDomain.training ? '每週次數' : '每週平均',
              readoutOf: (index) => switch (detail.values[index]) {
                final value? =>
                  '${_weekOf(detail.weekStarts[index])} · '
                      '${_valueOf(domain, value)}',
                null => '${_weekOf(detail.weekStarts[index])} · 沒有紀錄',
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
                  label: '平常範圍',
                ),
              if (baseline != null)
                _Key(color: AppColors.textSecondary, label: baselineLabel),
              if (recent != null) _Key(color: color, label: recentLabel),
            ],
          ),
          if (domain != TrendDomain.training && recentDays.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '近 4 週每週平均 '
              '${(recentDays.reduce((a, b) => a + b) / recentDays.length).toStringAsFixed(1)}'
              ' 天有紀錄',
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

  String get _label => switch (domain) {
    TrendDomain.body => '秤上體重',
    TrendDomain.training => '每週訓練量',
    TrendDomain.sleep => '',
    TrendDomain.nutrition => '蛋白質',
    TrendDomain.activity => '靜止心率',
  };

  String _value(double value) => switch (domain) {
    TrendDomain.body => '${formatWeight(_tenth(value))} kg',
    TrendDomain.training => '${formatKcal(value.round())} kg',
    TrendDomain.sleep => '',
    TrendDomain.nutrition => '${value.round()} g',
    TrendDomain.activity => '${value.round()} 次/分',
  };

  @override
  Widget build(BuildContext context) {
    final color = trendColor(domain);
    final latest = detail.values.nonNulls.lastOrNull;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_label, style: AppTextStyles.itemTitle),
              const Spacer(),
              if (latest != null)
                Text(_value(latest), style: AppTextStyles.body),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (latest == null)
            const Text('沒有紀錄', style: AppTextStyles.caption)
          else
            ChartScrubber(
              count: detail.values.length,
              indexAt: ChartScrubber.points(detail.values.length),
              idle: domain == TrendDomain.training ? '每週合計' : '每週平均',
              readoutOf: (index) => switch (detail.values[index]) {
                final value? =>
                  '${_weekOf(detail.weekStarts[index])} · ${_value(value)}',
                null => '${_weekOf(detail.weekStarts[index])} · 沒有紀錄',
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

  static const _names = ['一', '二', '三', '四', '五', '六', '日'];

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
                (_names[index], (((value ?? floor) - floor) * 100).round()),
            ],
            height: 80,
            color: color,
            dimColor: color.withValues(alpha: 0.4),
            selected: highest.$1,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '最高 週${_names[highest.$1]} ${_valueOf(domain, highest.$2)} · '
            '最低 週${_names[lowest.$1]} ${_valueOf(domain, lowest.$2)}',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
