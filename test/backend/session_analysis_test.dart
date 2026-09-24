import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/engines/session_analysis.dart';
import 'package:mishirube/backend/health/health_source.dart';
import 'package:mishirube/domain/domain.dart';

/// A route due north from the equator, [metersPerMinute] a minute, one
/// point a minute. A degree of latitude is about 111.2 km.
List<RoutePoint> _northward(int minutes, double metersPerMinute) => [
  for (var i = 0; i <= minutes; i++)
    (
      latitude: i * metersPerMinute / 111194.9,
      longitude: 0,
      altitude: 0,
      at: Duration(minutes: i),
      speed: metersPerMinute / 60,
    ),
];

void main() {
  test('a route is cut every kilometre, and a short end is its own', () {
    final heart = [
      for (var i = 0; i < 12; i++)
        (at: Duration(minutes: i), value: i < 4 ? 120.0 : 150.0),
    ];
    final splits = routeSplits(_northward(11, 250), heart);
    expect([
      for (final split in splits) (split.duration.inMilliseconds / 1000).round(),
    ], [240, 240, 180]);
    expect(splits.last.meters, closeTo(750, 1));
    expect(splits.first.averageHeartRate, 120);
    expect(splits[1].averageHeartRate, 150);
  });

  test('a last piece under 100 m is left off', () {
    expect(routeSplits(_northward(4, 260), const []).length, 1);
  });

  test('zones come from the heart rate reserve when resting is known', () {
    // Age 30: maximum 187. Resting 60: reserve 127.
    final heart = [
      for (final (minute, bpm) in [(0, 100.0), (1, 150.0), (2, 180.0), (3, 180.0)])
        (at: Duration(minutes: minute), value: bpm),
    ];
    final zones = heartRateZones(heart, age: 30, restingHeartRate: 60)!;
    expect(zones.lowerBounds, [124, 136, 149, 162, 174]);
    expect(zones.usesReserve, isTrue);
    expect(zones.durations, [
      const Duration(seconds: 30),
      Duration.zero,
      const Duration(seconds: 30),
      Duration.zero,
      const Duration(seconds: 30),
    ], reason: 'a reading counts until the next, at most 30 s');
    expect(heartRateZones(heart, age: null), isNull, reason: 'no maximum');
    expect(
      heartRateZones(heart, age: 30)!.lowerBounds,
      [94, 112, 131, 150, 168],
      reason: 'without a resting rate, shares of the maximum',
    );
  });

  test('a long series is averaged down to a drawable number of points', () {
    final points = [
      for (var i = 0; i < 1000; i++)
        (at: Duration(seconds: i), value: i.isEven ? 100.0 : 110.0),
    ];
    final shown = downsample(points, count: 100);
    expect(shown.length, 100);
    expect(shown.first.value, closeTo(105, 1));
    expect(rangeOf(points), (low: 100.0, high: 110.0, average: 105.0));
  });

  test('a platform detail reads what is there and skips what is not', () {
    final detail = parseActivityDetail({
      'activeMs': 571000,
      'device': 'Apple Watch',
      'place': '斗六市',
      'indoor': false,
      'temperature': 25.2,
      'humidity': 77.0,
      'elevationGain': 4.0,
      'figures': {'activeEnergy': 45.0, 'totalEnergy': 58.0, 'distance': 2500.0},
      'series': {
        'heartRate': [
          [0, 140],
          [5000, 142],
        ],
        'nonsense': [
          [0, 1],
        ],
        'recovery': [
          [0, 163],
          [60000, 148],
        ],
      },
      'route': [
        [23.7, 120.5, 52.0, 0, 4.1],
        [23.71, 120.51, 55.0, 60000, 4.6],
      ],
      'laps': [
        ['lap', 0, 207000],
      ],
      'effort': 6,
      'age': 30,
    });
    expect(detail.activeDuration, const Duration(minutes: 9, seconds: 31));
    expect(detail.totalKcal, 58);
    expect(detail.series.keys, {ActivitySeries.heartRate, ActivitySeries.altitude});
    expect(detail.recovery.last.value, 148);
    expect(detail.route.last.speed, 4.6);
    expect(detail.intervals.single.duration, const Duration(seconds: 207));
    expect(detail.effort, 6);
    expect(detail.age, 30);
  });
}
