import 'package:flutter/material.dart';

import '../../backend/engines/usual_range.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';

/// [points] (each day with a figure, oldest first, reaching four weeks
/// before [from]) drawn day by day from [from] through [to], each day
/// against the usual range of the four weeks before it (see
/// `research/85-normal-ranges-and-google-health-gaps.md`). A day without
/// a figure is a gap. With [summarises], how many days sat within it
/// says so at rest: only for readings of the body, not for a device's
/// estimate of sleep stages, where a ringed night is mostly the
/// estimate's own noise. Null without a figure to show.
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
  bool summarises = true,
  String? semanticLabel,
}) {
  final l10n = context.l10n;
  DateTime dayOf(DateTime time) => DateTime(time.year, time.month, time.day);
  final byDay = {for (final (at, value) in points) dayOf(at): value};
  final first = dayOf(from);
  final days = [
    for (
      var day = first;
      !day.isAfter(dayOf(to));
      day = DateTime(day.year, day.month, day.day + 1)
    )
      day,
  ];
  final values = [for (final day in days) byDay[day]];
  if (values.every((value) => value == null)) return null;
  final daily = [for (final (at, value) in points) (dayOf(at), value)];
  final ranges = [for (final day in days) usualRangeBefore(daily, day)];
  final judged = [
    for (final (index, value) in values.indexed)
      if (value != null) ?positionIn(value, ranges[index]),
  ];
  final within = judged.where((p) => p == UsualPosition.within).length;
  String summary() {
    if (judged.isEmpty) {
      final before = dayOf(to).subtract(usualRangeWindow);
      final count = byDay.keys
          .where((day) => !day.isBefore(before) && day.isBefore(dayOf(to)))
          .length;
      return isNightly
          ? l10n.usualRangeNeedsNights(count: count)
          : l10n.usualRangeNeedsDays(count: count);
    }
    if (judged.length == days.length) {
      return within == judged.length
          ? (isNightly
                ? l10n.nightsAllWithinUsual(count: within)
                : l10n.daysAllWithinUsual(count: within))
          : (isNightly
                ? l10n.nightsWithinUsual(count: within, total: days.length)
                : l10n.daysWithinUsual(count: within, total: days.length));
    }
    return isNightly
        ? l10n.nightsRecordedWithinUsual(recorded: judged.length, count: within)
        : l10n.daysRecordedWithinUsual(recorded: judged.length, count: within);
  }

  return UsualRangeTrend(
    label: label,
    color: color,
    days: days,
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
    readoutDay: context.dates.dayWithWeekday,
    summary: summarises
        ? summary()
        : (isNightly
              ? l10n.nightsCount(count: values.nonNulls.length)
              : l10n.daysCount(count: values.nonNulls.length)),
    semanticLabel: semanticLabel,
  );
}
