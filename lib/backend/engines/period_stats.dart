/// What a stretch of daily values comes to, for a trend page's figures:
/// how many days there are, their average and middle, the highest and
/// lowest day, and how widely they spread. Worked out on each read.
library;

import 'dart:math' as math;

class PeriodStats {
  const PeriodStats({
    required this.count,
    required this.mean,
    required this.median,
    required this.highest,
    required this.lowest,
    required this.spread,
  });

  /// Days with a value.
  final int count;
  final double mean;
  final double median;

  /// The day with the highest value and the one with the lowest; the
  /// later day when two tie.
  final (DateTime, double) highest;
  final (DateTime, double) lowest;

  /// The standard deviation, a day's usual distance from the average.
  final double spread;
}

/// [days]' figures; null without any.
PeriodStats? periodStats(List<(DateTime, double)> days) {
  if (days.isEmpty) return null;
  final values = [for (final (_, value) in days) value]..sort();
  final mean = values.fold(0.0, (sum, value) => sum + value) / values.length;
  final middle = values.length ~/ 2;
  var highest = days.first;
  var lowest = days.first;
  for (final day in days) {
    if (day.$2 >= highest.$2) highest = day;
    if (day.$2 <= lowest.$2) lowest = day;
  }
  final variance =
      values.fold(0.0, (sum, value) => sum + (value - mean) * (value - mean)) /
      values.length;
  return PeriodStats(
    count: values.length,
    mean: mean,
    median: values.length.isOdd
        ? values[middle]
        : (values[middle - 1] + values[middle]) / 2,
    highest: highest,
    lowest: lowest,
    spread: math.sqrt(variance),
  );
}

/// How many of [values] fall into each stretch [edges] cut: below the
/// first edge, between each pair, and from the last on. [edges] rise.
List<int> bucketCounts(Iterable<double> values, List<double> edges) {
  final counts = List.filled(edges.length + 1, 0);
  for (final value in values) {
    var bucket = 0;
    while (bucket < edges.length && value >= edges[bucket]) {
      bucket++;
    }
    counts[bucket]++;
  }
  return counts;
}
