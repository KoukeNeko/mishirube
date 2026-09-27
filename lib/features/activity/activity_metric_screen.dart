import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../backend/engines/activity_metrics.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import 'daily_activity_screen.dart';
import 'daily_activity_view_model.dart';
import '../../l10n/l10n.dart';

enum _Range {
  day(1),
  week(7),
  month(30),
  halfYear(182),
  year(365);

  const _Range(this.days);

  final int days;

  String labelIn(AppLocalizations l10n) => switch (this) {
    day => l10n.chartRangeDay,
    week => l10n.chartRangeWeek,
    month => l10n.chartRangeMonth,
    halfYear => l10n.chartRangeHalfYear,
    year => l10n.chartRangeYear,
  };
}

/// One activity metric over a day, a week, a month, half a year or a
/// year, ending with the day it was opened on. A day without a reading
/// is a gap, never a zero; long ranges are drawn as weekly or monthly
/// averages of the days that had one.
class ActivityMetricScreen extends StatefulWidget {
  const ActivityMetricScreen({
    super.key,
    required this.metric,
    required this.day,
  });

  final ActivityMetric metric;
  final DateTime day;

  @override
  State<ActivityMetricScreen> createState() => _ActivityMetricScreenState();
}

class _ActivityMetricScreenState extends State<ActivityMetricScreen> {
  late final _model = DailyActivityViewModel(
    AppStoreScope.read(context).backend,
    day: widget.day,
  );

  /// A measured metric has no hours: it is one figure a day.
  late var _range = widget.metric.isCumulative ? _Range.day : _Range.month;

  ActivityMetric get _metric => widget.metric;

  String _value(double value) =>
      '${_metric.format(value)} ${_metric.unitIn(context.l10n)}';

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
    final days = _model.daily(_metric, _range.days);
    final usual = _model.usualRange(_metric);
    return DetailPage(
      appBar: PageAppBar(
        title: _metric.labelIn(context.l10n),
        subtitle: context.dates.dayWithWeekday(day),
        actions: [
          HeaderAction(
            icon: Icons.chevron_left,
            semanticLabel: context.l10n.previousDay,
            onTap: () => _model.step(-1),
          ),
          HeaderAction(
            icon: Icons.chevron_right,
            semanticLabel: context.l10n.nextDay,
            onTap: _model.canGoForward ? () => _model.step(1) : null,
          ),
        ],
      ),
      children: [
        Gutter(
          child: SegmentedChoice<_Range>(
            options: [
              for (final range in _Range.values)
                if (_metric.isCumulative || range != _Range.day) range,
            ],
            selected: _range,
            labelOf: (range) => range.labelIn(context.l10n),
            onChanged: (range) => setState(() => _range = range),
            selectedColor: AppColors.activity,
          ),
        ),
        if (days.isEmpty)
          Gutter(
            child: GroupedCard(
              children: [
                KeyValueRow(
                  label: context.l10n.entriesRow,
                  value: context.l10n.noData,
                ),
              ],
            ),
          )
        else ...[
          Gutter(child: AppCard(child: _chart(days))),
          Gutter(
            child: GroupedCard(
              children: [
                if (_range == _Range.day)
                  KeyValueRow(
                    label: context.l10n.thisDay,
                    value: _value(days.single.$2),
                  )
                else
                  KeyValueRow(
                    label: context.l10n.dailyAverage,
                    value: _value(
                      days.fold(0.0, (sum, day) => sum + day.$2) / days.length,
                    ),
                  ),
                if (usual != null)
                  KeyValueRow(
                    label: context.l10n.usualRange,
                    value:
                        '${_metric.format(usual.low)}–'
                        '${_metric.format(usual.high)} ${_metric.unitIn(context.l10n)}',
                  ),
                if (_range != _Range.day)
                  KeyValueRow(
                    label: context.l10n.daysRecorded,
                    value: context.l10n.daysCount(count: days.length),
                  ),
                KeyValueRow(
                  label: context.l10n.journalSourceRow,
                  value: AppStoreScope.of(context).healthSourceName,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _chart(List<(DateTime, double)> days) {
    if (_range == _Range.day) {
      return HourlyActivityChart(
        metric: _metric,
        hours: _model.hourly(_metric) ?? List.filled(24, 0),
      );
    }
    final points = switch (_range) {
      _Range.halfYear => averagedBy(days, months: false),
      _Range.year => averagedBy(days, months: true),
      _ => days,
    };
    final dates = context.dates;
    final l10n = context.l10n;
    String when(DateTime start) => switch (_range) {
      _Range.halfYear => l10n.weekOf(date: dates.monthDay(start)),
      _Range.year => dates.yearMonth(start),
      _ => dates.dayWithWeekday(start),
    };
    final isAverage = _range == _Range.halfYear || _range == _Range.year;
    String figure(double value) =>
        isAverage ? l10n.statAverage(value: _value(value)) : _value(value);
    String readout(int index) {
      final (start, value) = points[index];
      return '${when(start)} · ${figure(value)}';
    }

    if (!_metric.isCumulative) {
      return ChartScrubber(
        count: points.length,
        indexAt: ChartScrubber.points(points.length),
        idle: l10n.readingsCount(count: points.length),
        readoutOf: readout,
        builder: (context, selected) => Sparkline(
          values: [for (final (_, value) in points) value],
          color: AppColors.activity,
          height: 80,
          selected: selected,
        ),
      );
    }
    // Every day of a short range gets its slot, so a day without a
    // reading shows as a gap where it falls.
    final slots = _range == _Range.week || _range == _Range.month
        ? _daySlots(points)
        : [for (final (start, value) in points) (start, value as double?)];
    return ChartScrubber(
      count: slots.length,
      indexAt: ChartScrubber.slots(slots.length),
      idle: isAverage ? l10n.dailyAverage : l10n.perDay,
      readoutOf: (index) => switch (slots[index]) {
        (final start, final value?) => '${when(start)} · ${figure(value)}',
        (final start, null) => '${when(start)} · ${l10n.noData}',
      },
      builder: (context, selected) => MiniBarChart(
        bars: [
          for (final (start, value) in slots)
            (
              _range == _Range.week ? dates.weekday(start) : '',
              ((value ?? 0) * 10).round(),
            ),
        ],
        height: 80,
        showLabels: _range == _Range.week,
        color: AppColors.activity,
        dimColor: AppColors.activity.withValues(alpha: 0.4),
        selected: selected,
      ),
    );
  }

  List<(DateTime, double?)> _daySlots(List<(DateTime, double)> points) {
    final byDay = {for (final (day, value) in points) day: value};
    final last = _model.day;
    return [
      for (var i = _range.days - 1; i >= 0; i--)
        () {
          final day = DateTime(last.year, last.month, last.day - i);
          return (day, byDay[day]);
        }(),
    ];
  }
}
