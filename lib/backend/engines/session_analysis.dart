import 'dart:math';

import '../../domain/domain.dart';

/// What a session's page works out from what the platform recorded:
/// splits along the route, time in each heart rate zone, and the range
/// of a series. Platforms give none of these for every session, so the
/// app derives them, and the page says which are the app's own.
///
/// Bumped whenever a rule below changes.
const sessionAnalysisVersion = 1;

/// A piece of the route: its length, how long it took, and the heart
/// rate over it when there was one.
typedef RouteSplit = ({
  int index,
  double meters,
  Duration duration,
  double? averageHeartRate,
});

/// A last piece shorter than this is left off the splits.
const _minimumLastSplitMeters = 100.0;

/// Longest gap between two heart rate readings still counted as time in
/// the zone of the first: past that the sensor lost contact.
const _longestReadingGap = Duration(seconds: 30);

const _earthRadiusMeters = 6371000.0;

double _metersBetween(RoutePoint a, RoutePoint b) {
  double radians(double degrees) => degrees * pi / 180;
  final dLat = radians(b.latitude - a.latitude);
  final dLon = radians(b.longitude - a.longitude);
  final h =
      pow(sin(dLat / 2), 2) +
      cos(radians(a.latitude)) *
          cos(radians(b.latitude)) *
          pow(sin(dLon / 2), 2);
  return 2 * _earthRadiusMeters * asin(sqrt(h));
}

/// The route cut every [splitMeters], with the time each piece took
/// (where a piece ends between two points, the time is interpolated) and
/// the average heart rate read during it.
List<RouteSplit> routeSplits(
  List<RoutePoint> route,
  List<SeriesPoint> heartRate, {
  double splitMeters = 1000,
}) {
  if (route.length < 2) return const [];
  final splits = <RouteSplit>[];
  var covered = 0.0;
  var splitStart = route.first.at;
  var splitStartMeters = 0.0;

  double? heartBetween(Duration from, Duration to) {
    final readings = [
      for (final point in heartRate)
        if (point.at >= from && point.at < to) point.value,
    ];
    if (readings.isEmpty) return null;
    return readings.reduce((a, b) => a + b) / readings.length;
  }

  void close(Duration end, double meters) {
    splits.add((
      index: splits.length + 1,
      meters: meters,
      duration: end - splitStart,
      averageHeartRate: heartBetween(splitStart, end),
    ));
    splitStart = end;
  }

  for (var i = 1; i < route.length; i++) {
    final step = _metersBetween(route[i - 1], route[i]);
    var stepStart = covered;
    covered += step;
    while (covered - splitStartMeters >= splitMeters) {
      final boundary = splitStartMeters + splitMeters;
      final fraction = step == 0 ? 1.0 : (boundary - stepStart) / step;
      final at =
          route[i - 1].at +
          (route[i].at - route[i - 1].at) * fraction.clamp(0.0, 1.0);
      close(at, splitMeters);
      splitStartMeters = boundary;
      stepStart = boundary;
    }
  }
  final rest = covered - splitStartMeters;
  if (rest >= _minimumLastSplitMeters) close(route.last.at, rest);
  return splits;
}

/// The five heart rate zones and the time spent in each, from the
/// heart rate reserve (maximum less resting) where the resting rate is
/// known, else from the maximum alone. The maximum is estimated from age
/// (208 − 0.7 × age, Tanaka 2001); null without an age or readings.
({List<int> lowerBounds, List<Duration> durations, bool usesReserve})?
heartRateZones(
  List<SeriesPoint> heartRate, {
  required int? age,
  double? restingHeartRate,
}) {
  if (age == null || heartRate.length < 2) return null;
  final maximum = 208 - 0.7 * age;
  final resting = restingHeartRate;
  // Zone 1 starts at 50%; each next zone at another tenth.
  const shares = [0.5, 0.6, 0.7, 0.8, 0.9];
  final bounds = [
    for (final share in shares)
      (resting == null
              ? maximum * share
              : resting + (maximum - resting) * share)
          .round(),
  ];
  final durations = List<Duration>.filled(shares.length, Duration.zero);
  for (var i = 0; i < heartRate.length - 1; i++) {
    final gap = heartRate[i + 1].at - heartRate[i].at;
    final counted = gap > _longestReadingGap ? _longestReadingGap : gap;
    final zone = bounds.lastIndexWhere((bound) => heartRate[i].value >= bound);
    // Below zone 1 counts as zone 1, as Apple's does.
    durations[max(zone, 0)] += counted;
  }
  return (
    lowerBounds: bounds,
    durations: durations,
    usesReserve: resting != null,
  );
}

/// The lowest, highest and average of [points]; null without any.
({double low, double high, double average})? rangeOf(List<SeriesPoint> points) {
  if (points.isEmpty) return null;
  final values = [for (final point in points) point.value];
  return (
    low: values.reduce(min),
    high: values.reduce(max),
    average: values.reduce((a, b) => a + b) / values.length,
  );
}

/// At most [count] points, each the average of the readings in its
/// stretch of time, so a long session draws as quickly as a short one.
List<SeriesPoint> downsample(List<SeriesPoint> points, {int count = 240}) {
  if (points.length <= count) return points;
  final start = points.first.at;
  final span = points.last.at - start;
  final buckets = List.generate(count, (_) => <double>[]);
  for (final point in points) {
    final index = span == Duration.zero
        ? 0
        : ((point.at - start).inMicroseconds /
                  span.inMicroseconds *
                  (count - 1))
              .round();
    buckets[index].add(point.value);
  }
  return [
    for (final (index, bucket) in buckets.indexed)
      if (bucket.isNotEmpty)
        (
          at: start + span * (index / (count - 1)),
          value: bucket.reduce((a, b) => a + b) / bucket.length,
        ),
  ];
}
