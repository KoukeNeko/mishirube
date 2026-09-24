import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../me/data_sources_screen.dart';
import 'activity_detail_screen.dart';
import 'activity_metric_screen.dart';
import 'daily_activity_view_model.dart';

/// A day's movement as the health platform counted it: the lead figure
/// hour by hour, every metric a source records, and the exercise done.
/// A metric no source records is not listed, so a device without a watch
/// shows what the device itself counts and nothing more.
class DailyActivityScreen extends StatefulWidget {
  const DailyActivityScreen({super.key, this.day});

  /// Which day to show; today when null.
  final DateTime? day;

  @override
  State<DailyActivityScreen> createState() => _DailyActivityScreenState();
}

class _DailyActivityScreenState extends State<DailyActivityScreen> {
  late final _model = DailyActivityViewModel(
    AppStoreScope.read(context).backend,
    day: widget.day,
  );

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: _model, builder: (context, _) => _page());

  Widget _page() {
    final day = _model.day;
    final metrics = _model.metrics;
    final totals = _model.totals;
    final sessions = _model.sessions;
    final lead = ActivityMetric.headline.where(totals.containsKey).firstOrNull;
    return DetailPage(
      appBar: PageAppBar(
        title: '活動',
        subtitle: '${day.month} 月 ${day.day} 日（週${weekdayLabel(day)}）',
        actions: [
          HeaderAction(
            icon: Icons.chevron_left,
            semanticLabel: '前一天',
            onTap: () => _model.step(-1),
          ),
          HeaderAction(
            icon: Icons.chevron_right,
            semanticLabel: '後一天',
            onTap: _model.canGoForward ? () => _model.step(1) : null,
          ),
        ],
      ),
      children: [
        if (metrics.isEmpty) ...[
          Gutter(
            child: const EmptyStateCard(
              icon: Icons.directions_walk,
              title: '沒有活動資料',
            ),
          ),
          Gutter(
            child: Center(
              child: LinkText(
                label: '資料來源',
                onTap: () => pushPage(context, const DataSourcesScreen()),
              ),
            ),
          ),
        ] else if (lead == null)
          Gutter(
            child: const EmptyStateCard(
              icon: Icons.directions_walk,
              title: '這一天沒有活動資料',
            ),
          )
        else
          Gutter(
            child: _LeadCard(
              metric: lead,
              totals: totals,
              hours: _model.hourly(lead) ?? List.filled(24, 0),
            ),
          ),
        for (final group in ActivityMetricGroup.values)
          if (metrics.where((metric) => metric.group == group).toList()
              case final inGroup when inGroup.isNotEmpty)
            PageSection(
              label: group.label,
              children: [
                Gutter(
                  child: GroupedCard(
                    children: [
                      for (final metric in inGroup)
                        NavRow(
                          title: metric.label,
                          subtitle: switch (_model.usualRange(metric)) {
                            final range? =>
                              '平常 ${metric.format(range.low)}–'
                                  '${metric.format(range.high)} ${metric.unit}',
                            null => null,
                          },
                          trailing: Text(switch (totals[metric]) {
                            final value? =>
                              '${metric.format(value)} ${metric.unit}',
                            null => '沒有資料',
                          }, style: AppTextStyles.caption),
                          onTap: () => pushPage(
                            context,
                            ActivityMetricScreen(metric: metric, day: day),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        if (sessions.isNotEmpty)
          PageSection(
            label: '運動',
            children: [
              Gutter(
                child: GroupedCard(
                  children: [
                    for (final session in sessions)
                      NavRow(
                        leading: Icon(
                          session.type.icon,
                          color: AppColors.activity,
                        ),
                        title: session.type.label,
                        subtitle:
                            '${formatTimeOfDay(session.startedAt)} · '
                            '${session.duration.inMinutes} 分',
                        onTap: () => pushPage(
                          context,
                          ActivityDetailScreen(activityId: session.id),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// The day's lead figure, the other counted ones beside it, and the lead
/// hour by hour.
class _LeadCard extends StatelessWidget {
  const _LeadCard({
    required this.metric,
    required this.totals,
    required this.hours,
  });

  final ActivityMetric metric;
  final Map<ActivityMetric, double> totals;
  final List<double> hours;

  @override
  Widget build(BuildContext context) {
    final others = [
      for (final other in ActivityMetric.headline)
        if (other != metric)
          if (totals[other] case final value?)
            '${other.format(value)} ${other.unit}',
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryLabel(label: metric.label, color: AppColors.activity),
          const SizedBox(height: AppSpacing.xs),
          ValueWithUnit(
            value: metric.format(totals[metric]!),
            unit: metric.unit,
            style: AppTextStyles.hugeNumber,
          ),
          if (others.isNotEmpty)
            Text(others.join(' · '), style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.md),
          HourlyActivityChart(metric: metric, hours: hours),
        ],
      ),
    );
  }
}

/// A counted metric's day in 24 bars; reading one says its hour.
class HourlyActivityChart extends StatelessWidget {
  const HourlyActivityChart({
    super.key,
    required this.metric,
    required this.hours,
  });

  final ActivityMetric metric;
  final List<double> hours;

  @override
  Widget build(BuildContext context) {
    return ChartScrubber(
      count: hours.length,
      indexAt: ChartScrubber.slots(hours.length),
      idle: '每小時',
      readoutOf: (hour) =>
          '$hour–${hour + 1} 時 · ${metric.format(hours[hour])} ${metric.unit}',
      builder: (context, selected) => Column(
        children: [
          MiniBarChart(
            bars: [for (final value in hours) ('', value.round())],
            height: 64,
            showLabels: false,
            color: AppColors.activity,
            dimColor: AppColors.activity.withValues(alpha: 0.4),
            selected: selected,
            highlightsLast: false,
          ),
          const SizedBox(height: AppSpacing.xxs),
          // A quarter of the width is six hours.
          Row(
            children: [
              for (final hour in const [0, 6, 12, 18])
                Expanded(child: Text('$hour 時', style: AppTextStyles.caption)),
            ],
          ),
        ],
      ),
    );
  }
}
