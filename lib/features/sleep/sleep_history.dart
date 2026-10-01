import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'sleep_schedule_chart.dart';
import 'sleep_screen.dart';
import 'sleep_view_model.dart';
import '../../l10n/l10n.dart';

/// How nights have gone over the [days] up to the day [model] shows, night
/// by night, for the sleep trend's week and month: each night's length
/// against the goal, and when each began and ended. Naps are not nights
/// and time in bed is not sleep, so neither is counted.
List<Widget> sleepNightItems(
  BuildContext context,
  SleepViewModel model,
  int days,
) {
  final l10n = context.l10n;
  final end = model.day.add(const Duration(days: 1));
  final start = end.subtract(Duration(days: days));
  final nights = model.nightsAsleep(days);
  if (nights.isEmpty) {
    return [
      Gutter(
        child: GroupedCard(
          children: [
            KeyValueRow(
              label: l10n.sleepMeasureAsleep,
              value: l10n.noEntriesShort,
            ),
          ],
        ),
      ),
    ];
  }
  final timed = [
    for (final night in nights)
      if (night.startedAt != null) night,
  ];
  return [
    Gutter(
      child: AppCard(child: _lengthChart(context, model, nights, start, days)),
    ),
    if (timed.length > 1)
      Gutter(child: AppCard(child: _scheduleChart(context, timed))),
  ];
}

/// Each night's length; reading a bar says its night.
Widget _lengthChart(
  BuildContext context,
  SleepViewModel model,
  List<SleepEntry> nights,
  DateTime start,
  int days,
) {
  final l10n = context.l10n;
  final bars = _bars(context, model, nights, start, days);
  final average =
      nights.fold(Duration.zero, (sum, night) => sum + night.duration) ~/
      nights.length;
  final goal = model.goal;
  final metCount = bars.where((bar) => bar.isMet).length;
  return ChartScrubber(
    count: bars.length,
    indexAt: ChartScrubber.slots(bars.length),
    idle: [
      l10n.statAverage(value: formatDuration(context.l10n, average)),
      l10n.nightsCount(count: nights.length),
      if (metCount > 0) l10n.goalMetNights(count: metCount),
    ].join(' · '),
    readoutOf: (index) => bars[index].readout,
    builder: (context, selected) => MiniBarChart(
      bars: [for (final bar in bars) (bar.label, bar.minutes)],
      height: 64,
      showLabels: days <= DateTime.daysPerWeek,
      color: AppColors.wellness,
      dimColor: AppColors.wellness.withValues(alpha: 0.4),
      selected: selected,
      goal: goal?.inMinutes,
      met: {
        for (final (index, bar) in bars.indexed)
          if (bar.isMet) index,
      },
    ),
  );
}

/// Each night from falling asleep to waking, with their average;
/// reading a row says its times.
Widget _scheduleChart(BuildContext context, List<SleepEntry> timed) {
  final l10n = context.l10n;
  // Bedtimes straddle midnight, so they are averaged from noon; waking
  // straddles nothing, so from midnight.
  final bedtime = _averageClock([
    for (final night in timed) night.startedAt!,
  ], fromHour: 12);
  final wake = _averageClock([
    for (final night in timed) night.sleptAt,
  ], fromHour: 0);
  return ChartScrubber(
    count: timed.length,
    indexAt: ChartScrubber.rows(
      timed.length,
      SleepScheduleChart.rowExtentFor(timed.length),
    ),
    idle:
        '${l10n.statAverage(value: '$bedtime–$wake')} · '
        '${l10n.nightsCount(count: timed.length)}',
    readoutOf: (index) {
      final night = timed[index];
      return '${context.dates.dayWithWeekday(night.sleptAt)} · '
          '${formatTimeOfDay(night.startedAt!)}–'
          '${formatTimeOfDay(night.sleptAt)} · '
          '${formatDuration(context.l10n, night.duration)}';
    },
    builder: (context, selected) =>
        SleepScheduleChart(nights: timed, selected: selected),
  );
}

/// One bar a night, each with what its reading says; a night without a
/// record is an empty bar, not a zero-hour night.
List<({String label, int? minutes, String readout, bool isMet})> _bars(
  BuildContext context,
  SleepViewModel model,
  List<SleepEntry> nights,
  DateTime start,
  int days,
) {
  DateTime dayOf(SleepEntry night) =>
      DateTime(night.sleptAt.year, night.sleptAt.month, night.sleptAt.day);
  final byDay = {
    for (final night in nights) dayOf(night): night.duration.inMinutes,
  };
  // Time in bed is not held against a goal for sleep.
  final goal = model.goal;
  final metDays = {
    for (final night in nights)
      if (goal != null &&
          night.measure == SleepMeasure.asleep &&
          night.duration >= goal)
        dayOf(night),
  };
  return [
    for (var i = 0; i < days; i++)
      () {
        final day = DateTime(start.year, start.month, start.day + i);
        return (
          label: context.dates.weekday(day),
          minutes: byDay[day],
          readout: [
            context.dates.dayWithWeekday(day),
            if (byDay[day] case final minutes?)
              formatDuration(context.l10n, Duration(minutes: minutes))
            else
              context.l10n.noEntriesShort,
            if (metDays.contains(day)) context.l10n.goalReached,
          ].join(' · '),
          isMet: metDays.contains(day),
        );
      }(),
  ];
}

/// The average time of day of [times], counted from [fromHour] so the
/// times fall in one unbroken stretch: from noon, 23:30 and 00:30 average
/// to midnight rather than noon.
String _averageClock(List<DateTime> times, {required int fromHour}) {
  const day = Duration.minutesPerDay;
  final from = fromHour * 60;
  final shifted = [
    for (final time in times) (time.hour * 60 + time.minute - from) % day,
  ];
  return formatMinutesOfDay(
    shifted.reduce((a, b) => a + b) ~/ shifted.length + from,
  );
}

/// Each overnight reading's nightly average across the [days] up to the
/// day [model] shows, behind it the usual range of the four weeks
/// before; a reading with fewer than two nights is left out.
List<Widget> sleepVitalItems(
  BuildContext context,
  SleepViewModel model,
  int days,
) {
  final l10n = context.l10n;
  final rows = [
    for (final measure in OvernightMeasure.values)
      if (measure != OvernightMeasure.breathingDisturbances)
        if (model.nightlyAverages(measure, days) case final values
            when values.length > 1)
          (measure, values),
  ];
  if (rows.isEmpty) return const [];
  String reading(OvernightMeasure measure, double value) =>
      withUnit(overnightNumber(measure, value), measure.unitIn(l10n));
  return [
    Gutter(child: SectionLabel(l10n.healthDataOvernight)),
    for (final (measure, readings) in rows)
      Gutter(
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryLabel(
                label: measure.labelIn(l10n),
                color: AppColors.wellness,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Semantics(
                label: l10n.trendOverNights(
                  measure: measure.labelIn(l10n),
                  count: readings.length,
                ),
                child: ChartScrubber(
                  count: readings.length,
                  indexAt: ChartScrubber.points(readings.length),
                  idle:
                      '${l10n.statAverage(value: reading(measure, readings.map((r) => r.$2).reduce((a, b) => a + b) / readings.length))}'
                      ' · ${l10n.nightsCount(count: readings.length)}',
                  readoutOf: (index) =>
                      '${context.dates.dayWithWeekday(readings[index].$1)} · '
                      '${reading(measure, readings[index].$2)}',
                  builder: (context, selected) => Sparkline(
                    values: [for (final (_, value) in readings) value],
                    color: AppColors.wellness,
                    height: 96,
                    selected: selected,
                    normal: switch (model.baseline(measure)) {
                      final usual? => (usual.low, usual.high),
                      null => null,
                    },
                  ),
                ),
              ),
              if (model.baseline(measure) != null) ...[
                const SizedBox(height: AppSpacing.xs),
                ChartKey(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  label: l10n.usualRange,
                ),
              ],
            ],
          ),
        ),
      ),
  ];
}

/// Nights after training, late caffeine or a late meal against the
/// others, with how many nights each side has. Only what both sides
/// have enough nights for.
List<Widget> sleepFactorItems(BuildContext context, SleepViewModel model) {
  final l10n = context.l10n;
  final factors = model.factors;
  String signed(Duration difference) => difference.isNegative
      ? l10n.sleptLess(time: formatDuration(context.l10n, -difference))
      : l10n.sleptMore(time: formatDuration(context.l10n, difference));
  final rows = [
    for (final (label, comparison) in [
      (l10n.afterTraining, factors.training),
      (l10n.caffeineAfter2pm, factors.lateCaffeine),
      (l10n.mealAfter9pm, factors.lateMeal),
    ])
      if (comparison != null)
        KeyValueRow(
          label: label,
          value:
              '${signed(comparison.difference)} · '
              '${l10n.nightsVersus(withCount: comparison.withCount, withoutCount: comparison.withoutCount)}',
        ),
  ];
  if (rows.isEmpty) return const [];
  return [
    Gutter(child: SectionLabel(l10n.factorsSection)),
    Gutter(child: GroupedCard(children: rows)),
    Gutter(
      child: TagWrap(labels: [l10n.factorsBasis, l10n.correlationNotCause]),
    ),
  ];
}
