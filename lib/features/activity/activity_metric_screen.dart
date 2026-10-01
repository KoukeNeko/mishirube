import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../backend/engines/activity_metrics.dart';
import '../../backend/engines/overnight_series.dart';
import '../../backend/engines/usual_range.dart';
import '../trends/usual_range_trend.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'daily_activity_screen.dart';
import 'daily_activity_view_model.dart';
import 'step_goal_row.dart';
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
    halfYear => l10n.monthsCount(count: 6),
    year => l10n.yearsCount(count: 1),
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

  /// A measured metric has no hours: it is one figure a day. Heart rate
  /// is the exception: its day is read through, sample by sample.
  late var _range = widget.metric.isCumulative || _hasDaySeries
      ? _Range.day
      : _Range.month;

  /// Readings of the body a watch takes every day: how many days sat in
  /// their usual range is worth a sentence. A sparse one (an estimated
  /// VO₂ max, a walking test) rarely reaches the days a range needs.
  bool get _isDailyReading => const {
    ActivityMetric.heartRate,
    ActivityMetric.restingHeartRate,
    ActivityMetric.walkingHeartRate,
    ActivityMetric.hrvSdnn,
    ActivityMetric.hrvRmssd,
    ActivityMetric.respiratoryRate,
    ActivityMetric.oxygenSaturation,
    ActivityMetric.bodyTemperature,
  }.contains(_metric);

  /// Heart rate's day is drawn from the platform's own samples, as the
  /// night's is on the sleep page.
  bool get _hasDaySeries => widget.metric == ActivityMetric.heartRate;

  ActivityMetric get _metric => widget.metric;

  /// The heart and the vitals are drawn in their own colours, as Apple
  /// Health draws them; what the body did, in the activity colour.
  Color get _color => switch (_metric) {
    ActivityMetric.respiratoryRate ||
    ActivityMetric.oxygenSaturation => AppColors.breathing,
    _ => switch (_metric.group) {
      ActivityMetricGroup.heart ||
      ActivityMetricGroup.vitals => AppColors.heart,
      _ => AppColors.activity,
    },
  };

  /// Blood pressure is read as the pair it is taken as: opened from its
  /// systolic figure, the page shows the diastolic beside it.
  bool get _isBloodPressure => _metric == ActivityMetric.bloodPressureSystolic;

  /// A daily step goal the user chose, drawn on the steps' days.
  int? get _stepGoal =>
      _metric == ActivityMetric.steps ? _model.stepGoal : null;

  /// Days that reached the step goal: a floor, so a day still going
  /// that is past it has reached it.
  bool _meetsGoal(double? value) => switch ((_stepGoal, value)) {
    (final goal?, final steps?) => steps >= goal,
    _ => false,
  };

  String _value(double value) =>
      withUnit(_metric.format(value), _metric.unitIn(context.l10n));

  /// The diastolic figure of each day [days] has, for blood pressure.
  Map<DateTime, double> _diastolic(int days) => {
    for (final (day, value) in _model.daily(
      ActivityMetric.bloodPressureDiastolic,
      days,
    ))
      day: value,
  };

  /// [systolic] with its day's diastolic, `120/80 mmHg`; the systolic
  /// alone when the pair is not there.
  String _pair(double systolic, double? diastolic) => diastolic == null
      ? _value(systolic)
      : '${systolic.round()}/${diastolic.round()} mmHg';

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
    // The user's own last four weeks, never a population norm, and only
    // for a reading of the body: a count with a goal is read against the
    // goal, and blood pressure is a pair one band cannot stand for.
    final usual = _isBloodPressure || _metric.isCumulative
        ? null
        : _model.usualRange(_metric);
    final diastolic = _isBloodPressure
        ? _diastolic(_range.days)
        : const <DateTime, double>{};
    double? mean(Iterable<double> values) => values.isEmpty
        ? null
        : values.fold(0.0, (sum, value) => sum + value) / values.length;
    // A count that adds up through the day is not a day's yet today, so
    // the average leaves today out while there are other days.
    final averaged = _metric.isCumulative && days.length > 1
        ? [
            for (final entry in days)
              if (entry.$1 != _model.today) entry,
          ]
        : days;
    return DetailPage(
      appBar: PageAppBar(
        title: _isBloodPressure
            ? context.l10n.vitalBloodPressure
            : _metric.labelIn(context.l10n),
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
                if (_metric.isCumulative ||
                    _hasDaySeries ||
                    range != _Range.day)
                  range,
            ],
            selected: _range,
            labelOf: (range) => range.labelIn(context.l10n),
            onChanged: (range) => setState(() => _range = range),
            selectedColor: _color,
          ),
        ),
        if (_hasDaySeries && _range == _Range.day)
          Gutter(
            child: AppCard(child: HeartRateDayChart(day: day)),
          )
        else if (days.isEmpty)
          Gutter(
            child: GroupedCard(
              children: [
                KeyValueRow(
                  label: context.l10n.entriesRow,
                  value: context.l10n.noEntriesShort,
                ),
              ],
            ),
          )
        else ...[
          Gutter(child: AppCard(child: _chart(days, usual))),
          if (_metric == ActivityMetric.steps)
            Gutter(
              child: GroupedCard(children: [stepGoalRow(context, _model)]),
            ),
          Gutter(
            child: GroupedCard(
              children: [
                if (_range == _Range.day)
                  KeyValueRow(
                    label: context.l10n.thisDay,
                    value: _isBloodPressure
                        ? _pair(days.single.$2, diastolic[days.single.$1])
                        : _value(days.single.$2),
                  )
                else
                  KeyValueRow(
                    label: context.l10n.dailyAverage,
                    value: _isBloodPressure
                        ? _pair(
                            mean([for (final (_, v) in days) v])!,
                            mean(diastolic.values),
                          )
                        : _value(mean([for (final (_, v) in averaged) v])!),
                  ),
                if (usual != null)
                  KeyValueRow(
                    label: context.l10n.usualRange,
                    value: withUnit(
                      '${_metric.format(usual.low)}–'
                      '${_metric.format(usual.high)}',
                      _metric.unitIn(context.l10n),
                    ),
                  ),
                if (_range != _Range.day)
                  KeyValueRow(
                    label: context.l10n.daysRecorded,
                    value: context.l10n.daysCount(count: days.length),
                  ),
                // Finished days only: today can still get there.
                if (_stepGoal != null &&
                    (_range == _Range.week || _range == _Range.month))
                  if ([
                        for (final (day, steps) in days)
                          if (day.isBefore(_model.today)) steps,
                      ]
                      case final finished when finished.isNotEmpty)
                    KeyValueRow(
                      label: context.l10n.stepGoalMetLabel,
                      value: context.l10n.daysOutOf(
                        count: finished.where(_meetsGoal).length,
                        total: finished.length,
                      ),
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

  Widget _chart(
    List<(DateTime, double)> days,
    ({double low, double high})? usual,
  ) {
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
    final diastolic = _isBloodPressure
        ? _diastolic(_range.days)
        : const <DateTime, double>{};
    // Blood pressure's two lines share one axis of days; averaged ranges
    // pair each stretch's averages the same way.
    final lower = !_isBloodPressure
        ? const <(DateTime, double)>[]
        : switch (_range) {
            _Range.halfYear => averagedBy([
              for (final e in diastolic.entries) (e.key, e.value),
            ], months: false),
            _Range.year => averagedBy([
              for (final e in diastolic.entries) (e.key, e.value),
            ], months: true),
            _ => [for (final e in diastolic.entries) (e.key, e.value)],
          };
    final lowerAt = {for (final (start, value) in lower) start: value};
    String readout(int index) {
      final (start, value) = points[index];
      return '${when(start)} · '
          '${_isBloodPressure ? _pair(value, lowerAt[start]) : figure(value)}';
    }

    // A reading of the body, day by day, is set against what was usual
    // in the four weeks before each day.
    if (!_metric.isCumulative &&
        !_isBloodPressure &&
        (_range == _Range.week || _range == _Range.month)) {
      if (usualRangeTrend(
            context,
            color: _color,
            points: _model.daily(
              _metric,
              _range.days + usualRangeWindow.inDays,
            ),
            from: _model.day.subtract(Duration(days: _range.days - 1)),
            to: _model.day,
            format: _value,
            formatRange: (low, high) => withUnit(
              '${_metric.format(low)}–${_metric.format(high)}',
              _metric.unitIn(l10n),
            ),
            isNightly: false,
            summarises: _isDailyReading,
          )
          case final trend?) {
        return trend;
      }
    }
    if (!_metric.isCumulative) {
      return ChartScrubber(
        count: points.length,
        indexAt: ChartScrubber.points(points.length),
        idle: l10n.readingsCount(count: points.length),
        readoutOf: readout,
        builder: (context, selected) => Column(
          children: [
            Sparkline(
              values: [for (final (_, value) in points) value],
              color: _color,
              height: 80,
              selected: selected,
              normal: switch (usual) {
                (:final low, :final high) => (low, high),
                null => null,
              },
            ),
            if (_isBloodPressure) ...[
              const SizedBox(height: AppSpacing.xs),
              // 0.7 keeps the paler line at 3:1 against the card.
              Sparkline(
                values: [for (final (start, _) in points) lowerAt[start]],
                color: _color.withValues(alpha: 0.7),
                height: 48,
                selected: selected,
              ),
            ],
          ],
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
        (final start, final value?) => [
          when(start),
          figure(value),
          if (!isAverage && _meetsGoal(value)) l10n.goalReached,
        ].join(' · '),
        (final start, null) => '${when(start)} · ${l10n.noEntriesShort}',
      },
      builder: (context, selected) => MiniBarChart(
        bars: [
          for (final (start, value) in slots)
            (
              _range == _Range.week ? dates.weekday(start) : '',
              value == null ? null : (value * 10).round(),
            ),
        ],
        height: 80,
        showLabels: _range == _Range.week,
        color: _color,
        dimColor: _color.withValues(alpha: 0.4),
        selected: selected,
        goal: _stepGoal == null ? null : _stepGoal! * 10,
        met: {
          if (!isAverage)
            for (final (index, (_, value)) in slots.indexed)
              if (_meetsGoal(value)) index,
        },
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

/// Stretches a day's heart rate is drawn in: half an hour each.
const _heartRateBins = 48;

/// A day's heart rate from the health platform, half an hour to a bar
/// from its lowest to its highest reading, as the night's is drawn on
/// the sleep page; read when the day is shown, its bars holding their
/// place while the platform answers.
class HeartRateDayChart extends StatefulWidget {
  const HeartRateDayChart({super.key, required this.day});

  /// Midnight of the day drawn.
  final DateTime day;

  @override
  State<HeartRateDayChart> createState() => _HeartRateDayChartState();
}

class _HeartRateDayChartState extends State<HeartRateDayChart> {
  late Future<List<(DateTime, double)>> _samples = _read();

  DateTime get _from =>
      DateTime(widget.day.year, widget.day.month, widget.day.day);
  DateTime get _to =>
      DateTime(widget.day.year, widget.day.month, widget.day.day + 1);

  Future<List<(DateTime, double)>> _read() async =>
      (await AppStoreScope.read(context)
          .overnightSeries(_from, _to))[OvernightMeasure.heartRate] ??
      const [];

  @override
  void didUpdateWidget(HeartRateDayChart old) {
    super.didUpdateWidget(old);
    if (old.day != widget.day) _samples = _read();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final unit = ActivityMetric.heartRate.unitIn(l10n);
    String bpm(double value) => withUnit('${value.round()}', unit);
    return FutureBuilder(
      future: _samples,
      builder: (context, snapshot) {
        final points = snapshot.data ?? const <(DateTime, double)>[];
        final ranges = rangeBins(points, _from, _to, bins: _heartRateBins);
        final values = [for (final (_, value) in points) value];
        final stretch = _to.difference(_from) ~/ _heartRateBins;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              values.isEmpty
                  ? (snapshot.connectionState == ConnectionState.done
                        ? l10n.noEntriesShort
                        : '—')
                  : withUnit(
                      '${values.reduce(math.min).round()}–'
                      '${values.reduce(math.max).round()}',
                      unit,
                    ),
              style: AppTextStyles.bigNumber,
            ),
            const SizedBox(height: AppSpacing.md),
            ChartScrubber(
              count: ranges.length,
              indexAt: ChartScrubber.slots(ranges.length),
              idle: l10n.everyMinutes(minutes: stretch.inMinutes),
              readoutOf: (index) {
                final start = _from.add(stretch * index);
                return [
                  '${formatTimeOfDay(start)}–'
                      '${formatTimeOfDay(start.add(stretch))}',
                  switch (ranges[index]) {
                    (final low, final high) when low == high => bpm(low),
                    (final low, final high) => withUnit(
                      '${low.round()}–${high.round()}',
                      unit,
                    ),
                    null => l10n.noEntriesShort,
                  },
                ].join(' · ');
              },
              builder: (context, selected) => RangeBarChart(
                ranges: ranges,
                color: AppColors.heart,
                labelOf: (value) => '${value.round()}',
                start: '00:00',
                end: '24:00',
                selected: selected,
              ),
            ),
          ],
        );
      },
    );
  }
}
