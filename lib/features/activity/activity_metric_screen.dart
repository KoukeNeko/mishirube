import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../backend/engines/activity_metrics.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'daily_activity_screen.dart';
import 'daily_activity_view_model.dart';

enum _Range {
  day('日', 1),
  week('週', 7),
  month('月', 30),
  halfYear('半年', 182),
  year('年', 365);

  const _Range(this.label, this.days);

  final String label;
  final int days;
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

  String _value(double value) => '${_metric.format(value)} ${_metric.unit}';

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
        title: _metric.label,
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
        Gutter(
          child: SegmentedChoice<_Range>(
            options: [
              for (final range in _Range.values)
                if (_metric.isCumulative || range != _Range.day) range,
            ],
            selected: _range,
            labelOf: (range) => range.label,
            onChanged: (range) => setState(() => _range = range),
            selectedColor: AppColors.activity,
          ),
        ),
        if (days.isEmpty)
          Gutter(
            child: const GroupedCard(
              children: [KeyValueRow(label: '紀錄', value: '沒有資料')],
            ),
          )
        else ...[
          Gutter(child: AppCard(child: _chart(days))),
          Gutter(
            child: GroupedCard(
              children: [
                if (_range == _Range.day)
                  KeyValueRow(label: '這一天', value: _value(days.single.$2))
                else
                  KeyValueRow(
                    label: '每日平均',
                    value: _value(
                      days.fold(0.0, (sum, day) => sum + day.$2) / days.length,
                    ),
                  ),
                if (usual != null)
                  KeyValueRow(
                    label: '平常範圍',
                    value:
                        '${_metric.format(usual.low)}–'
                        '${_metric.format(usual.high)} ${_metric.unit}',
                  ),
                if (_range != _Range.day)
                  KeyValueRow(label: '紀錄天數', value: '${days.length} 天'),
                KeyValueRow(
                  label: '來源',
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
    String when(DateTime start) => switch (_range) {
      _Range.halfYear => '${start.month} 月 ${start.day} 日起一週',
      _Range.year => '${start.year} 年 ${start.month} 月',
      _ => '${start.month} 月 ${start.day} 日（週${weekdayLabel(start)}）',
    };
    final isAverage = _range == _Range.halfYear || _range == _Range.year;
    String readout(int index) {
      final (start, value) = points[index];
      return '${when(start)} · ${isAverage ? '平均 ' : ''}${_value(value)}';
    }

    if (!_metric.isCumulative) {
      return ChartScrubber(
        count: points.length,
        indexAt: ChartScrubber.points(points.length),
        idle: '${points.length} 筆',
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
      idle: isAverage ? '每日平均' : '每日',
      readoutOf: (index) => switch (slots[index]) {
        (final start, final value?) =>
          '${when(start)} · ${isAverage ? '平均 ' : ''}${_value(value)}',
        (final start, null) => '${when(start)} · 沒有資料',
      },
      builder: (context, selected) => MiniBarChart(
        bars: [
          for (final (start, value) in slots)
            (
              _range == _Range.week ? weekdayLabel(start) : '',
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
