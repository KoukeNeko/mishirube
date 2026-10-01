import 'package:flutter/material.dart';

import '../../backend/engines/usual_range.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';

/// [points] (each day with a figure, oldest first) drawn from [from]
/// through [to], each day against the usual range of the four weeks
/// before it (see `research/85-normal-ranges-and-google-health-gaps.md`),
/// so [points] reach four weeks before [from]. [weekly] draws each week
/// from [from] as the average of its days instead, against the 26 weeks
/// before it, and [points] reach that far: half a year of single days
/// is too dense to read. A slot without a figure is a gap. With
/// [summarises], how many days sat within it says so at rest: only for
/// readings of the body day by day, not for a device's estimate of sleep
/// stages, where a ringed night is mostly the estimate's own noise.
/// Otherwise the line says the average. Null without a figure to show.
UsualRangeTrend? usualRangeTrend(
  BuildContext context, {
  String? label,
  required Color color,
  required List<(DateTime, double)> points,
  required DateTime from,
  required DateTime to,
  required String Function(double value) format,
  required String Function(double low, double high) formatRange,
  required bool isNightly,
  bool weekly = false,
  bool summarises = true,
  String? semanticLabel,
}) {
  final l10n = context.l10n;
  DateTime dayOf(DateTime time) => DateTime(time.year, time.month, time.day);
  final first = dayOf(from);
  final last = dayOf(to);
  // Counted in calendar days, so a clock change does not shift a week.
  DateTime slotOf(DateTime day) {
    if (!weekly) return day;
    final offset = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).difference(DateTime.utc(first.year, first.month, first.day)).inDays;
    final week = (offset / DateTime.daysPerWeek).floor();
    return DateTime(
      first.year,
      first.month,
      first.day + week * DateTime.daysPerWeek,
    );
  }

  double mean(Iterable<double> values) =>
      values.fold(0.0, (sum, value) => sum + value) / values.length;
  final grouped = <DateTime, List<double>>{};
  for (final (at, value) in points) {
    (grouped[slotOf(dayOf(at))] ??= []).add(value);
  }
  final bySlot = {
    for (final MapEntry(key: slot, value: values) in grouped.entries)
      slot: mean(values),
  };
  final step = weekly ? DateTime.daysPerWeek : 1;
  final slots = [
    for (
      var slot = first;
      !slot.isAfter(last);
      slot = DateTime(slot.year, slot.month, slot.day + step)
    )
      slot,
  ];
  final values = [for (final slot in slots) bySlot[slot]];
  if (values.every((value) => value == null)) return null;
  final history = [
    for (final MapEntry(:key, :value) in bySlot.entries) (key, value),
  ];
  final ranges = [
    for (final slot in slots)
      weekly
          ? usualRangeBefore(
              history,
              slot,
              window: weeklyUsualRangeWindow,
              minimum: weeklyUsualRangeMinimumWeeks,
            )
          : usualRangeBefore(history, slot),
  ];
  final shown = [
    for (final (at, value) in points)
      if (!dayOf(at).isBefore(first) && !dayOf(at).isAfter(last)) value,
  ];
  String average() => [
    l10n.statAverage(value: format(mean(shown))),
    isNightly
        ? l10n.nightsCount(count: shown.length)
        : l10n.daysCount(count: shown.length),
  ].join(' · ');
  String summary() {
    final judged = [
      for (final (index, value) in values.indexed)
        if (value != null) ?positionIn(value, ranges[index]),
    ];
    final within = judged.where((p) => p == UsualPosition.within).length;
    if (judged.isEmpty) {
      final before = last.subtract(usualRangeWindow);
      final count = bySlot.keys
          .where((day) => !day.isBefore(before) && day.isBefore(last))
          .length;
      return isNightly
          ? l10n.usualRangeNeedsNights(count: count)
          : l10n.usualRangeNeedsDays(count: count);
    }
    if (judged.length == slots.length) {
      return within == judged.length
          ? (isNightly
                ? l10n.nightsAllWithinUsual(count: within)
                : l10n.daysAllWithinUsual(count: within))
          : (isNightly
                ? l10n.nightsWithinUsual(count: within, total: slots.length)
                : l10n.daysWithinUsual(count: within, total: slots.length));
    }
    return isNightly
        ? l10n.nightsRecordedWithinUsual(recorded: judged.length, count: within)
        : l10n.daysRecordedWithinUsual(recorded: judged.length, count: within);
  }

  return UsualRangeTrend(
    label: label,
    color: color,
    days: slots,
    values: values,
    bands: [
      for (final range in ranges)
        if (range case (:final low, :final high)) (low, high) else null,
    ],
    format: format,
    formatRange: formatRange,
    usualLabel: l10n.usualRange,
    outsideLabel: l10n.outsideUsual,
    usualValue: (range) => l10n.usualRangeValue(range: range),
    noValue: l10n.noEntriesShort,
    readoutDay: weekly
        ? (start) => l10n.weekFrom(date: context.dates.compactMonthDay(start))
        : context.dates.dayWithWeekday,
    summary: summarises && !weekly ? summary() : average(),
    semanticLabel: semanticLabel,
  );
}
