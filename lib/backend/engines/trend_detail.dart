/// One area's figure week by week, for the page a long-run line opens
/// (see `research/56-trends-insights.md`): the weekly values, the range
/// that is normal for this person, where the latest stretch and the
/// baseline before it sit, and how the days of the week differ. Worked
/// out from the records on each read.
library;

import 'usual_range.dart';

/// How a week's records make one value: an average of its days (sleep,
/// steps), or a count over the week (workouts).
enum WeekAggregate { mean, sum }

/// A stretch of weeks drawn as one level on the chart: Apple Health's
/// "you used to average this, now this", rather than a fitted line.
class TrendLevel {
  const TrendLevel({
    required this.value,
    required this.fromWeek,
    required this.toWeek,
  });

  final double value;

  /// The first and last week it covers, as indexes into the weeks.
  final int fromWeek;
  final int toWeek;
}

class TrendDetail {
  const TrendDetail({
    required this.weekStarts,
    required this.values,
    required this.daysWithRecords,
    required this.normal,
    required this.recent,
    required this.baseline,
    required this.weekdays,
  });

  /// The first day of each week, oldest first, the last week ending
  /// today.
  final List<DateTime> weekStarts;

  /// Each week's value; null for a week without records.
  final List<double?> values;

  /// How many days of each week have a record.
  final List<int> daysWithRecords;

  /// The lowest to the highest week of the half year before the latest
  /// stretch: what is normal for this person. Null with too few weeks
  /// to say.
  final (double, double)? normal;

  /// The latest stretch and the baseline before it, when the weeks
  /// reach that far.
  final TrendLevel? recent;
  final TrendLevel? baseline;

  /// Monday first: each weekday's average (or, for a count, how often a
  /// week has one on that day). Null for a weekday without records.
  final List<double?> weekdays;
}

DateTime _dayOf(DateTime time) => DateTime(time.year, time.month, time.day);

double _mean(Iterable<double> values) =>
    values.fold(0.0, (sum, value) => sum + value) / values.length;

/// [daily] in the [weeks] weeks from [start], one value a week by
/// [aggregate], with the days of each week that had a record. A count is
/// zero in a week without any, but only once records began.
({List<double?> values, List<int> days}) _weekly(
  List<(DateTime, double)> daily,
  DateTime start,
  int weeks,
  WeekAggregate aggregate,
) {
  final end = start.add(Duration(days: weeks * DateTime.daysPerWeek));
  final byWeek = List.generate(weeks, (_) => <double>[]);
  final daysByWeek = List.generate(weeks, (_) => <DateTime>{});
  DateTime? first;
  for (final (at, value) in daily) {
    final day = _dayOf(at);
    if (day.isBefore(start) || !day.isBefore(end)) continue;
    final week = day.difference(start).inDays ~/ DateTime.daysPerWeek;
    byWeek[week].add(value);
    daysByWeek[week].add(day);
    if (first == null || day.isBefore(first)) first = day;
  }
  final firstWeek = first == null
      ? weeks
      : first.difference(start).inDays ~/ DateTime.daysPerWeek;
  return (
    values: [
      for (var week = 0; week < weeks; week++)
        switch (aggregate) {
          WeekAggregate.mean =>
            byWeek[week].isEmpty ? null : _mean(byWeek[week]),
          WeekAggregate.sum =>
            week < firstWeek
                ? null
                : byWeek[week].fold<double>(0, (sum, value) => sum + value),
        },
    ],
    days: [for (final days in daysByWeek) days.length],
  );
}

/// [daily] over the last [weeks] weeks up to [today], aggregated by
/// [aggregate]. The latest [recentWeeks] are set against the
/// [baselineWeeks] before them, or, when [baselineIncludesRecent], the
/// [baselineWeeks] ending today. What is normal for this person is the
/// lowest to the highest of the [weeklyUsualRangeWeeks] weeks before the
/// latest stretch, read from [daily] even where that reaches back past
/// the weeks shown.
TrendDetail trendDetail(
  List<(DateTime, double)> daily,
  DateTime today, {
  required int weeks,
  required WeekAggregate aggregate,
  int recentWeeks = 4,
  int baselineWeeks = 12,
  bool baselineIncludesRecent = false,
}) {
  final end = _dayOf(today);
  final start = end.subtract(Duration(days: weeks * DateTime.daysPerWeek - 1));
  final shown = _weekly(daily, start, weeks, aggregate);
  final values = shown.values;
  final byWeekday = List.generate(DateTime.daysPerWeek, (_) => <double>[]);
  for (final (at, value) in daily) {
    final day = _dayOf(at);
    if (day.isBefore(start) || day.isAfter(end)) continue;
    byWeekday[day.weekday - 1].add(value);
  }
  final firstWeek = values.indexWhere((value) => value != null);
  final countedWeeks = firstWeek < 0 ? 0 : weeks - firstWeek;
  final weekdays = [
    for (final values in byWeekday)
      switch (aggregate) {
        WeekAggregate.mean => values.isEmpty ? null : _mean(values),
        WeekAggregate.sum =>
          countedWeeks <= 0
              ? null
              : values.fold(0.0, (sum, value) => sum + value) / countedWeeks,
      },
  ];

  TrendLevel? levelOver(int from, int to) {
    if (from < 0) return null;
    final covered = [for (var week = from; week <= to; week++) ?values[week]];
    // Half the weeks at least, so a level is not one lucky week.
    if (covered.length * 2 < to - from + 1) return null;
    return TrendLevel(value: _mean(covered), fromWeek: from, toWeek: to);
  }

  final recentFrom = weeks - recentWeeks;
  final baselineTo = baselineIncludesRecent ? weeks - 1 : recentFrom - 1;
  final usualStart = start.add(
    Duration(days: (recentFrom - weeklyUsualRangeWeeks) * DateTime.daysPerWeek),
  );
  final usual = usualRangeOf([
    ..._weekly(
      daily,
      usualStart,
      weeklyUsualRangeWeeks,
      aggregate,
    ).values.nonNulls,
  ], minimum: weeklyUsualRangeMinimumWeeks);
  return TrendDetail(
    weekStarts: [
      for (var week = 0; week < weeks; week++)
        start.add(Duration(days: week * DateTime.daysPerWeek)),
    ],
    values: values,
    daysWithRecords: shown.days,
    normal: usual == null ? null : (usual.low, usual.high),
    recent: levelOver(recentFrom, weeks - 1),
    baseline: levelOver(baselineTo - baselineWeeks + 1, baselineTo),
    weekdays: weekdays,
  );
}
