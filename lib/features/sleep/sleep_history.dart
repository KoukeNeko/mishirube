import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../backend/engines/sleep_metrics.dart';
import '../../backend/engines/usual_range.dart';
import '../trends/usual_range_trend.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'sleep_schedule_chart.dart';
import 'sleep_stage_chart.dart';
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
      Gutter(
        child: AppCard(child: _scheduleChart(context, timed, targetsOf(model))),
      ),
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
Widget _scheduleChart(
  BuildContext context,
  List<SleepEntry> timed,
  List<int> targets,
) {
  final l10n = context.l10n;
  // Bedtimes straddle midnight, so they are averaged from noon; waking
  // straddles nothing, so from midnight.
  final bedtime = _averageClock([
    for (final night in timed) night.startedAt!,
  ], fromHour: 12);
  final wake = _averageClock([
    for (final night in timed) night.sleptAt,
  ], fromHour: 0);
  final chart = ChartScrubber(
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
        SleepScheduleChart(nights: timed, selected: selected, targets: targets),
  );
  if (targets.isEmpty) return chart;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      chart,
      const SizedBox(height: AppSpacing.xs),
      targetKey(context),
    ],
  );
}

/// The schedule the user aims for, as minutes after midnight; empty
/// until set.
List<int> targetsOf(SleepViewModel model) => [
  ?model.targetBedtime,
  ?model.targetWake,
];

/// The legend for a target schedule's lines.
Widget targetKey(BuildContext context) => ChartKey(
  color: AppColors.textPrimary.withValues(alpha: 0.7),
  label: context.l10n.targetSchedule,
);

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

/// The nights before the [days] up to the day shown that a usual range
/// for their first is drawn from.
int _withRangeHistory(int days, {required bool weekly}) =>
    days + (weekly ? weeklyUsualRangeWindow : usualRangeWindow).inDays;

/// Each overnight reading's nightly average across the [days] up to the
/// day [model] shows, behind it the usual range of the four weeks
/// before; [weekly] reads them week by week from the first. A reading
/// with fewer than two nights or weeks is left out.
List<Widget> sleepVitalItems(
  BuildContext context,
  SleepViewModel model,
  int days, {
  bool weekly = false,
}) {
  final l10n = context.l10n;
  final first = model.day.subtract(Duration(days: days - 1));
  final shownFrom = DateTime(first.year, first.month, first.day);
  final trends = [
    for (final measure in OvernightMeasure.values)
      if (measure != OvernightMeasure.breathingDisturbances)
        if (usualRangeTrend(
              context,
              label: measure.labelIn(l10n),
              color: AppColors.wellness,
              points: model.nightlyAverages(
                measure,
                _withRangeHistory(days, weekly: weekly),
              ),
              from: shownFrom,
              to: model.day,
              isNightly: true,
              weekly: weekly,
              semanticLabel: l10n.trendOverNights(
                measure: measure.labelIn(l10n),
                count: days,
              ),
              format: (value) => withUnit(
                overnightNumber(measure, value),
                measure.unitIn(l10n),
              ),
              formatRange: (low, high) => withUnit(
                '${overnightNumber(measure, low)}–'
                '${overnightNumber(measure, high)}',
                measure.unitIn(l10n),
              ),
            )
            case final trend? when trend.values.nonNulls.length > 1)
          trend,
  ];
  if (trends.isEmpty) return const [];
  return [
    Gutter(child: SectionLabel(l10n.healthDataOvernight)),
    for (final trend in trends) Gutter(child: AppCard(child: trend)),
  ];
}

/// Nights after training, caffeine at bedtime, a late meal, a nap, a bath or
/// daylight against the others, with how many nights each side has. A
/// factor whose sides are too small says so rather than going missing.
List<Widget> sleepFactorItems(BuildContext context, SleepViewModel model) {
  final l10n = context.l10n;
  final factors = model.factors;
  String value(
    SleepComparison? comparison, {
    String Function({required String time})? shorter,
    String Function({required String time})? longer,
    String? tag,
  }) {
    if (comparison == null) return l10n.notEnoughData;
    final nights = l10n.nightsVersus(
      withCount: comparison.withCount,
      withoutCount: comparison.withoutCount,
    );
    final difference = comparison.difference;
    if (difference == null) return '${l10n.notEnoughData} · $nights';
    final length = formatDuration(l10n, difference.abs());
    final figure = difference.isNegative
        ? (shorter ?? l10n.sleptLess)(time: length)
        : (longer ?? l10n.sleptMore)(time: length);
    return [figure, nights, ?tag].join(' · ');
  }

  return [
    Gutter(child: SectionLabel(l10n.factorsSection)),
    Gutter(
      child: GroupedCard(
        children: [
          for (final (label, comparison) in [
            (l10n.afterTraining, factors.training),
            (l10n.caffeineAtBedtime, factors.caffeineAtBedtime),
            (l10n.mealAfter9pm, factors.lateMeal),
            (l10n.napThatDay, factors.nap),
          ])
            KeyValueRow(label: label, value: value(comparison)),
          KeyValueRow(
            label: l10n.recordBath,
            value: value(
              factors.bath.comparison,
              shorter: l10n.fallAsleepShorter,
              longer: l10n.fallAsleepLonger,
              tag: factors.bath.isMostlyUnrecorded
                  ? l10n.bathWaterUnknownTag
                  : null,
            ),
          ),
          KeyValueRow(label: l10n.moreDaylight, value: value(factors.daylight)),
        ],
      ),
    ),
    Gutter(
      child: TagWrap(labels: [l10n.factorsBasis, l10n.correlationNotCause]),
    ),
  ];
}

/// Each staged night's time in deep sleep, REM and light or core sleep,
/// and its efficiency, over the [days] up to the day [model] shows, each
/// against what was usual for this person in the four weeks before that
/// night: a band that moves with the nights, and nights apart from it
/// ringed; [weekly] reads them week by week from the first. Stages are
/// a device's estimate, so they are read against the person's own
/// nights, never a population's (see
/// `research/85-normal-ranges-and-google-health-gaps.md`). A figure
/// with fewer than two nights or weeks is left out.
List<Widget> sleepStageItems(
  BuildContext context,
  SleepViewModel model,
  int days, {
  bool weekly = false,
}) {
  final l10n = context.l10n;
  final nights = model.nightlyStages(_withRangeHistory(days, weekly: weekly));
  final firstShown = model.day.subtract(Duration(days: days - 1));
  final shownFrom = DateTime(firstShown.year, firstShown.month, firstShown.day);
  String length(double minutes) =>
      formatDuration(l10n, Duration(minutes: minutes.round()));
  String percent(double value) => '${value.round()}%';
  final series = [
    for (final stage in [SleepStage.deep, SleepStage.rem, SleepStage.core])
      (
        stage.labelIn(l10n),
        sleepStageColor(stage),
        [
          for (final night in nights)
            (
              night.morning,
              night.stages[stage]?.inMinutes.toDouble() ??
                  (stage == SleepStage.core
                      ? night.stages[SleepStage.asleep]?.inMinutes.toDouble()
                      : null),
            ),
        ],
        length,
      ),
    (
      l10n.sleepEfficiency,
      AppColors.wellness,
      [
        for (final night in nights)
          (
            night.morning,
            switch (night.efficiency) {
              final value? => value * 100,
              null => null,
            },
          ),
      ],
      percent,
    ),
  ];
  final trends = [
    for (final (label, color, points, format) in series)
      // A device's estimate: drawn against its usual range, with no
      // sentence saying how many nights fit it.
      if (usualRangeTrend(
            context,
            label: label,
            color: color,
            points: [
              for (final (morning, value) in points)
                if (value != null) (morning, value),
            ],
            from: shownFrom,
            to: model.day,
            format: format,
            formatRange: (low, high) => '${format(low)}–${format(high)}',
            isNightly: true,
            weekly: weekly,
            summarises: false,
          )
          case final trend? when trend.values.nonNulls.length > 1)
        trend,
  ];
  if (trends.isEmpty) return const [];
  return [
    Gutter(child: SectionLabel(l10n.sleepStagesSection)),
    for (final trend in trends) Gutter(child: AppCard(child: trend)),
  ];
}
