import '../../domain/domain.dart';

/// Bumped whenever a rule below changes, so a stored or exported result can
/// say which version produced it.
const trendEngineVersion = 1;

/// Below this many measurements a trend is not reported at all.
const minimumPointsForTrend = 4;

/// How many days a week has, spelled out where it is a rate conversion.
const _daysPerWeek = 7;

/// A measured series over a window, and the straight-line rate through it.
class MeasurementTrend {
  const MeasurementTrend({
    required this.values,
    required this.days,
    required this.changePerWeek,
  });

  static const empty = MeasurementTrend(
    values: [],
    days: 0,
    changePerWeek: null,
  );

  /// Measurements in the window, oldest first.
  final List<double> values;

  /// Length of the window in days, for saying what the trend covers.
  final int days;

  /// Least-squares slope in units per week; null when there is too little
  /// data to say anything.
  final double? changePerWeek;

  double? get latest => values.isEmpty ? null : values.last;

  double? get change => values.length < 2 ? null : values.last - values.first;
}

/// Fits a line through [weights] measured in `[now - window, now]`.
MeasurementTrend weightTrend(
  Iterable<BodyWeight> weights, {
  required DateTime now,
  required Duration window,
}) {
  final start = now.subtract(window);
  final points = [
    for (final weight in weights)
      if (!weight.measuredAt.isBefore(start) && !weight.measuredAt.isAfter(now))
        (
          weight.measuredAt.difference(start).inMinutes /
              Duration.minutesPerDay,
          weight.weightKg,
        ),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return MeasurementTrend(
    values: [for (final point in points) point.$2],
    days: window.inDays,
    changePerWeek: points.length < minimumPointsForTrend
        ? null
        : _slopePerDay(points)! * _daysPerWeek,
  );
}

/// Least-squares slope of `y` over `x`; null when every x is the same.
double? _slopePerDay(List<(double, double)> points) {
  final meanX = points.map((p) => p.$1).reduce((a, b) => a + b) / points.length;
  final meanY = points.map((p) => p.$2).reduce((a, b) => a + b) / points.length;
  var covariance = 0.0;
  var variance = 0.0;
  for (final (x, y) in points) {
    covariance += (x - meanX) * (y - meanY);
    variance += (x - meanX) * (x - meanX);
  }
  return variance == 0 ? null : covariance / variance;
}

/// One week of a weekly chart: its label and what was counted in it.
typedef WeeklyBar = (String, int);

/// Counts [events] into the [weeks] whole weeks ending with the one holding
/// [now]. Weeks run Monday to Sunday; the last bar is labelled 本週.
List<WeeklyBar> weeklyCounts(
  Iterable<DateTime> events, {
  required DateTime now,
  required int weeks,
}) {
  final thisWeek = _startOfWeek(now);
  final counts = List.filled(weeks, 0);
  for (final event in events) {
    final week = _startOfWeek(event);
    final index =
        weeks - 1 - (thisWeek.difference(week).inDays ~/ _daysPerWeek);
    if (index >= 0 && index < weeks) counts[index]++;
  }
  return [
    for (final (index, count) in counts.indexed)
      (
        index == weeks - 1
            ? '本週'
            : _label(
                thisWeek.subtract(Duration(days: (weeks - 1 - index) * 7)),
              ),
        count,
      ),
  ];
}

/// Sums per-day amounts into the same weeks [weeklyCounts] uses.
List<WeeklyBar> weeklySums(
  Iterable<(DateTime, int)> amounts, {
  required DateTime now,
  required int weeks,
}) {
  final bars = weeklyCounts(const [], now: now, weeks: weeks);
  final totals = List.filled(weeks, 0);
  final thisWeek = _startOfWeek(now);
  for (final (day, amount) in amounts) {
    final index =
        weeks -
        1 -
        (thisWeek.difference(_startOfWeek(day)).inDays ~/ _daysPerWeek);
    if (index >= 0 && index < weeks) totals[index] += amount;
  }
  return [for (final (index, bar) in bars.indexed) (bar.$1, totals[index])];
}

DateTime _startOfWeek(DateTime day) {
  final date = DateTime(day.year, day.month, day.day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

String _label(DateTime day) => '${day.month}/${day.day}';
