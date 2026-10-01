import '../../domain/domain.dart';

DateTime _dayOf(DateTime time) => DateTime(time.year, time.month, time.day);

/// Each local day with a figure, oldest first: a counted metric's
/// buckets added up, a measured one's averaged. A day without samples is
/// absent, not zero — nothing was read for it.
List<(DateTime, double)> dailyValues(List<ActivitySample> samples) {
  final byDay = <DateTime, List<double>>{};
  for (final sample in samples) {
    byDay.putIfAbsent(_dayOf(sample.start), () => []).add(sample.value);
  }
  final days = byDay.keys.toList()..sort();
  return [
    for (final day in days)
      (
        day,
        switch (byDay[day]!) {
          final values when samples.first.metric.isCumulative => values.fold(
            0.0,
            (sum, value) => sum + value,
          ),
          final values =>
            values.fold(0.0, (sum, value) => sum + value) / values.length,
        },
      ),
  ];
}

/// A counted metric's day in 24 hourly totals, by the local hour each
/// bucket began in; an hour nothing was counted in is zero.
List<double> hourlyValues(List<ActivitySample> samples) {
  final hours = List<double>.filled(24, 0);
  for (final sample in samples) {
    hours[sample.start.hour] += sample.value;
  }
  return hours;
}

/// Groups [days] into weeks starting on Monday, or into months, each the
/// average of the days that had a figure: a long range drawn day by day
/// is noise.
List<(DateTime, double)> averagedBy(
  List<(DateTime, double)> days, {
  required bool months,
}) {
  final groups = <DateTime, List<double>>{};
  for (final (day, value) in days) {
    final key = months
        ? DateTime(day.year, day.month)
        : DateTime(day.year, day.month, day.day - (day.weekday - 1));
    groups.putIfAbsent(key, () => []).add(value);
  }
  final keys = groups.keys.toList()..sort();
  return [
    for (final key in keys)
      (
        key,
        groups[key]!.fold(0.0, (sum, value) => sum + value) /
            groups[key]!.length,
      ),
  ];
}
