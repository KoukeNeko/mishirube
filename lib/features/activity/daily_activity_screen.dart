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
import '../../l10n/l10n.dart';

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
    return PageScaffold(
      appBar: PageAppBar(
        title: context.l10n.dailyActivityTitle,
        subtitle: context.dates.dayWithWeekday(day),
      ),
      // The same week header as 睡眠 and 飲食: any day is a swipe away.
      pinned: WeekDayStrip(
        selected: day,
        latest: _model.today,
        firstWeekday: AppStoreScope.of(context).firstWeekday,
        color: AppColors.activity,
        markedDays: _model.daysWithActivity([
          for (var back = -35; back <= 35; back++)
            DateTime(day.year, day.month, day.day + back),
        ]),
        onSelected: _model.show,
      ),
      pinnedHeight: WeekDayStrip.pinnedHeightOf(context),
      children: [
        if (metrics.isEmpty) ...[
          Gutter(
            child: EmptyStateCard(
              icon: Icons.directions_walk,
              title: context.l10n.noActivityData,
            ),
          ),
          Gutter(
            child: Center(
              child: LinkText(
                label: context.l10n.dataSourcesLink,
                onTap: () => pushPage(context, const DataSourcesScreen()),
              ),
            ),
          ),
        ] else if (lead == null)
          Gutter(
            child: EmptyStateCard(
              icon: Icons.directions_walk,
              title: context.l10n.noActivityThisDay,
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
        // Vitals describe the body, not what it did: they are on its page.
        for (final group in ActivityMetricGroup.values)
          if (group != ActivityMetricGroup.vitals)
            if (metrics.where((metric) => metric.group == group).toList()
                case final inGroup when inGroup.isNotEmpty)
              PageSection(
                label: group.labelIn(context.l10n),
                children: [
                  Gutter(
                    child: GroupedCard(
                      children: [
                        for (final metric in inGroup)
                          NavRow(
                            title: metric.labelIn(context.l10n),
                            subtitle: switch (_model.usualRange(metric)) {
                              final range? => context.l10n.usualRangeValue(
                                range: withUnit(
                                  '${metric.format(range.low)}–'
                                  '${metric.format(range.high)}',
                                  metric.unitIn(context.l10n),
                                ),
                              ),
                              null => null,
                            },
                            trailing: Text(switch (totals[metric]) {
                              final value? => withUnit(
                                metric.format(value),
                                metric.unitIn(context.l10n),
                              ),
                              null => context.l10n.noEntriesShort,
                            }, style: AppTextStyles.itemTitle),
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
            label: context.l10n.moduleActivity,
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
                        title: session.type.labelIn(context.l10n),
                        subtitle:
                            '${formatTimeOfDay(session.startedAt)} · '
                            '${context.l10n.durationMinutes(minutes: session.duration.inMinutes)}',
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
            withUnit(other.format(value), other.unitIn(context.l10n)),
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryLabel(
            label: metric.labelIn(context.l10n),
            color: AppColors.activity,
          ),
          const SizedBox(height: AppSpacing.xs),
          ValueWithUnit(
            value: metric.format(totals[metric]!),
            unit: metric.unitIn(context.l10n),
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
      idle: context.l10n.perHour,
      readoutOf: (hour) =>
          '${context.l10n.hourSpan(start: hour, end: hour + 1)} · '
          '${withUnit(metric.format(hours[hour]), metric.unitIn(context.l10n))}',
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
                Expanded(
                  child: Text(
                    context.l10n.hourOfDay(hour: hour),
                    style: AppTextStyles.caption,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
