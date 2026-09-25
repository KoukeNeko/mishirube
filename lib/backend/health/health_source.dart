import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/domain.dart';
import '../storage/database.dart';

/// A health platform the app reads from. Read only: nothing is written
/// back.
abstract interface class HealthSource {
  /// What the user calls it: `Apple 健康`, `Health Connect`.
  String get name;

  /// Where the records it produces say they came from.
  ChangeSource get changeSource;

  /// Put in front of every id it produces, so two platforms never
  /// collide and a re-read finds what it wrote before.
  String get idPrefix;

  /// The kinds this platform can hold.
  Set<HealthDataKind> get kinds;

  /// Whether this device has the platform, ready to use.
  Future<bool> isAvailable();

  /// Asks for read access. True when the request went through; neither
  /// platform says which kinds were allowed, so an empty read afterwards
  /// may also mean "not allowed".
  Future<bool> requestAccess(Set<HealthDataKind> kinds);

  /// The kinds the user allowed, or null when the platform will not
  /// say: Apple Health keeps read permission private on purpose, so an
  /// app cannot tell "not allowed" from "nothing recorded".
  Future<Set<HealthDataKind>?> grantedKinds();

  /// Calls [show] whenever the platform asks the app to explain how it
  /// uses health data — at once if it opened the app for that, and each
  /// time after. Health Connect does this from its permission screens.
  Future<void> onPrivacyRequest(void Function() show);

  Future<List<SleepSample>> sleepSamples(DateTime from, DateTime to);

  /// What was measured over each of [windows], one list per window, in
  /// the statistic the platform reports each measure in.
  Future<List<List<OvernightReading>>> overnight(
    List<(DateTime, DateTime)> windows,
  );
  Future<List<HealthWeight>> weights(DateTime from, DateTime to);
  Future<List<HealthWaist>> waists(DateTime from, DateTime to);
  Future<List<HealthBodyReading>> bodyReadings(DateTime from, DateTime to);
  Future<List<HealthWorkout>> workouts(DateTime from, DateTime to);
  Future<List<HealthWater>> water(DateTime from, DateTime to);

  /// Every [ActivityMetric] the platform keeps over [from]–[to]: counted
  /// ones as hourly totals ([isHourly]) or daily ones, measured ones as
  /// daily averages, all from the platform's own statistics so a phone
  /// and a watch count once.
  Future<List<ActivitySample>> activitySamples(
    DateTime from,
    DateTime to, {
    bool isHourly = true,
  });

  /// Everything the platform recorded during the workout it calls
  /// [platformId]; null when it no longer has it.
  Future<ActivityDetail?> activityDetail(String platformId);

  /// Heart rate and respiratory rate through [from]–[to], sample by
  /// sample, oldest first; a measure the platform has none of is absent.
  Future<Map<OvernightMeasure, List<(DateTime, double)>>> overnightSeries(
    DateTime from,
    DateTime to,
  );
}

/// A platform reached through a method channel. Apple Health
/// (`HealthKitBridge` in `ios/Runner/AppDelegate.swift`) and Health
/// Connect (`HealthConnectBridge.kt` on Android) answer the same calls
/// with the same shapes, so one class reads both.
class PlatformHealthSource implements HealthSource {
  const PlatformHealthSource._(
    this._channel,
    this._isThisPlatform, {
    required this.name,
    required this.changeSource,
    required this.idPrefix,
    required this.kinds,
  });

  /// Apple Health on iOS, or Health Connect on Android.
  factory PlatformHealthSource.forThisDevice() =>
      Platform.isAndroid ? healthConnect : appleHealth;

  static final appleHealth = PlatformHealthSource._(
    const MethodChannel('mishirube/healthkit'),
    () => Platform.isIOS,
    name: 'Apple 健康',
    changeSource: ChangeSource.healthKit,
    idPrefix: 'healthkit',
    kinds: HealthDataKind.values.toSet(),
  );

  /// Health Connect has no waist circumference record, and no exercise
  /// minutes, walking heart rate or SDNN variability; its absent metrics
  /// just never come back from a read.
  static final healthConnect = PlatformHealthSource._(
    const MethodChannel('mishirube/healthconnect'),
    () => Platform.isAndroid,
    name: 'Health Connect',
    changeSource: ChangeSource.healthConnect,
    idPrefix: 'healthconnect',
    kinds: {...HealthDataKind.values}..remove(HealthDataKind.waist),
  );

  @override
  final String name;
  @override
  final ChangeSource changeSource;
  @override
  final String idPrefix;
  @override
  final Set<HealthDataKind> kinds;
  final MethodChannel _channel;
  final bool Function() _isThisPlatform;

  @override
  Future<bool> isAvailable() async {
    if (!_isThisPlatform()) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> requestAccess(Set<HealthDataKind> kinds) async =>
      await _channel.invokeMethod<bool>('requestAccess', {
        'kinds': [for (final kind in kinds) kind.name],
      }) ??
      false;

  @override
  Future<Set<HealthDataKind>?> grantedKinds() async {
    final names = await _channel.invokeListMethod<String>('grantedKinds');
    if (names == null) return null;
    final byName = HealthDataKind.values.asNameMap();
    return {for (final name in names) ?byName[name]};
  }

  @override
  Future<void> onPrivacyRequest(void Function() show) async {
    if (!_isThisPlatform()) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'showPrivacy') show();
    });
    try {
      if (await _channel.invokeMethod<bool>('takePrivacyRequest') ?? false) {
        show();
      }
    } on MissingPluginException {
      return;
    }
  }

  Future<List<Map<Object?, Object?>>> _read(
    HealthDataKind kind,
    DateTime from,
    DateTime to, {
    bool daily = false,
  }) async =>
      await _channel.invokeListMethod<Map<Object?, Object?>>('read', {
        'kind': kind.name,
        'from': from.millisecondsSinceEpoch,
        'to': to.millisecondsSinceEpoch,
        if (daily) 'daily': true,
      }) ??
      const [];

  static DateTime _time(Object? ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms! as int);

  @override
  Future<List<SleepSample>> sleepSamples(DateTime from, DateTime to) async => [
    for (final row in await _read(HealthDataKind.sleep, from, to))
      if (SleepStage.values.asNameMap()[row['stage']] case final stage?)
        SleepSample(
          start: _time(row['start']),
          end: _time(row['end']),
          stage: stage,
          native: row['native'] as String? ?? '',
          source: row['source'] as String? ?? '',
          sourceName: row['sourceName'] as String? ?? '',
          isManual: row['manual'] == true,
        ),
  ];

  @override
  Future<List<List<OvernightReading>>> overnight(
    List<(DateTime, DateTime)> windows,
  ) async {
    final result = [for (final _ in windows) <OvernightReading>[]];
    if (windows.isEmpty) return result;
    final rows =
        await _channel.invokeListMethod<Map<Object?, Object?>>('overnight', {
          'windows': [
            for (final (start, end) in windows)
              [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
          ],
        }) ??
        const [];
    final byName = OvernightMeasure.values.asNameMap();
    for (final row in rows) {
      final index = row['window']! as int;
      final measure = byName[row['measure']];
      if (measure == null || index < 0 || index >= windows.length) continue;
      result[index].add(
        OvernightReading(
          measure: measure,
          minimum: (row['min']! as num).toDouble(),
          maximum: (row['max']! as num).toDouble(),
          average: (row['avg']! as num).toDouble(),
          count: row['count']! as int,
          isElevated: row['elevated'] as bool?,
        ),
      );
    }
    return result;
  }

  @override
  Future<List<HealthWeight>> weights(DateTime from, DateTime to) async => [
    for (final row in await _read(HealthDataKind.weight, from, to))
      HealthWeight(
        id: row['id']! as String,
        at: _time(row['at']),
        kg: (row['kg']! as num).toDouble(),
      ),
  ];

  @override
  Future<List<HealthWaist>> waists(DateTime from, DateTime to) async => [
    for (final row in await _read(HealthDataKind.waist, from, to))
      HealthWaist(
        id: row['id']! as String,
        at: _time(row['at']),
        cm: (row['cm']! as num).toDouble(),
      ),
  ];

  @override
  Future<List<HealthBodyReading>> bodyReadings(
    DateTime from,
    DateTime to,
  ) async {
    final metrics = BodyMetric.values.asNameMap();
    return [
      for (final row in await _read(HealthDataKind.body, from, to))
        if (metrics[row['metric']] case final metric?)
          HealthBodyReading(
            id: row['id']! as String,
            at: _time(row['at']),
            metric: metric,
            value: (row['value']! as num).toDouble(),
          ),
    ];
  }

  @override
  Future<List<HealthWorkout>> workouts(DateTime from, DateTime to) async => [
    for (final row in await _read(HealthDataKind.workouts, from, to))
      HealthWorkout(
        id: row['id']! as String,
        start: _time(row['start']),
        end: _time(row['end']),
        activity: row['activity']! as String,
        nativeType: row['native']! as String,
        distanceMeters: (row['distance'] as num?)?.toDouble(),
      ),
  ];

  @override
  Future<List<HealthWater>> water(DateTime from, DateTime to) async => [
    for (final row in await _read(HealthDataKind.water, from, to))
      HealthWater(
        id: row['id']! as String,
        at: _time(row['at']),
        ml: (row['ml']! as num).round(),
      ),
  ];

  @override
  Future<Map<OvernightMeasure, List<(DateTime, double)>>> overnightSeries(
    DateTime from,
    DateTime to,
  ) async {
    if (!_isThisPlatform()) return const {};
    final rows =
        await _channel.invokeMapMethod<Object?, Object?>('overnightSeries', {
          'from': from.millisecondsSinceEpoch,
          'to': to.millisecondsSinceEpoch,
        }) ??
        const {};
    final byName = OvernightMeasure.values.asNameMap();
    return {
      for (final MapEntry(key: name, value: points) in rows.entries)
        if ((byName[name], points) case (final measure?, final List points))
          measure: [
            for (final point in points)
              if (point case [final num at, final num value])
                (
                  DateTime.fromMillisecondsSinceEpoch(at.toInt()),
                  value.toDouble(),
                ),
          ],
    };
  }

  @override
  Future<ActivityDetail?> activityDetail(String platformId) async {
    final row = await _channel.invokeMapMethod<Object?, Object?>(
      'workoutDetail',
      {'id': platformId},
    );
    return row == null ? null : parseActivityDetail(row);
  }

  @override
  Future<List<ActivitySample>> activitySamples(
    DateTime from,
    DateTime to, {
    bool isHourly = true,
  }) async {
    final metrics = ActivityMetric.values.asNameMap();
    return [
      for (final row in await _read(
        HealthDataKind.activity,
        from,
        to,
        daily: !isHourly,
      ))
        if (metrics[row['metric']] case final metric?)
          ActivitySample(
            metric: metric,
            start: _time(row['start']),
            end: _time(row['end']),
            value: (row['value']! as num).toDouble(),
          ),
    ];
  }
}

/// No platform: tests and previews.
class NoHealthSource implements HealthSource {
  const NoHealthSource();

  @override
  String get name => '健康資料';
  @override
  ChangeSource get changeSource => ChangeSource.healthKit;
  @override
  String get idPrefix => 'none';
  @override
  Set<HealthDataKind> get kinds => const {};

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> requestAccess(Set<HealthDataKind> kinds) async => false;

  @override
  Future<Set<HealthDataKind>?> grantedKinds() async => const {};

  @override
  Future<void> onPrivacyRequest(void Function() show) async {}

  @override
  Future<List<SleepSample>> sleepSamples(DateTime from, DateTime to) async =>
      const [];
  @override
  Future<List<List<OvernightReading>>> overnight(
    List<(DateTime, DateTime)> windows,
  ) async => [for (final _ in windows) const []];
  @override
  Future<List<HealthWeight>> weights(DateTime from, DateTime to) async =>
      const [];
  @override
  Future<List<HealthWaist>> waists(DateTime from, DateTime to) async =>
      const [];
  @override
  Future<List<HealthBodyReading>> bodyReadings(
    DateTime from,
    DateTime to,
  ) async => const [];
  @override
  Future<List<HealthWorkout>> workouts(DateTime from, DateTime to) async =>
      const [];
  @override
  Future<List<HealthWater>> water(DateTime from, DateTime to) async => const [];
  @override
  Future<List<ActivitySample>> activitySamples(
    DateTime from,
    DateTime to, {
    bool isHourly = true,
  }) async => const [];
  @override
  Future<ActivityDetail?> activityDetail(String platformId) async => null;

  @override
  Future<Map<OvernightMeasure, List<(DateTime, double)>>> overnightSeries(
    DateTime from,
    DateTime to,
  ) async => const {};
}

/// A workout's detail as both platform bridges send it. Anything
/// missing or malformed is left out rather than failing the page.
ActivityDetail parseActivityDetail(Map<Object?, Object?> row) {
  double? number(Object? value) => (value as num?)?.toDouble();
  Duration offset(Object? ms) => Duration(milliseconds: (ms! as num).round());
  List<SeriesPoint> points(Object? rows) => [
    for (final point in (rows as List?) ?? const [])
      if (point is List && point.length >= 2)
        (at: offset(point[0]), value: (point[1] as num).toDouble()),
  ];
  final figures = (row['figures'] as Map?) ?? const {};
  final seriesRows = (row['series'] as Map?) ?? const {};
  final seriesByName = ActivitySeries.values.asNameMap();
  final route = [
    for (final point in (row['route'] as List?) ?? const [])
      if (point is List && point.length >= 5)
        (
          latitude: (point[0] as num).toDouble(),
          longitude: (point[1] as num).toDouble(),
          altitude: (point[2] as num).toDouble(),
          at: offset(point[3]),
          speed: (point[4] as num).toDouble(),
        ),
  ];
  return ActivityDetail(
    activeDuration: row['activeMs'] == null ? null : offset(row['activeMs']),
    device: row['device'] as String?,
    place: row['place'] as String?,
    isIndoor: row['indoor'] as bool?,
    temperatureCelsius: number(row['temperature']),
    humidityPercent: number(row['humidity']),
    elevationGainMeters: number(row['elevationGain']),
    activeKcal: number(figures['activeEnergy']),
    totalKcal: number(figures['totalEnergy']),
    distanceMeters: number(figures['distance']),
    steps: number(figures['steps']),
    swimmingStrokes: number(figures['swimmingStrokes']),
    lapLengthMeters: number(row['lapLength']),
    series: {
      for (final MapEntry(:key, :value) in seriesRows.entries)
        if (seriesByName[key] case final series?)
          if (points(value) case final found when found.isNotEmpty)
            series: found,
      // Without speed samples, the speed GPS measured along the route.
      if (!seriesRows.containsKey('speed') &&
          route.any((point) => point.speed > 0))
        ActivitySeries.speed: [
          for (final point in route) (at: point.at, value: point.speed),
        ],
      if (route.any((point) => point.altitude != 0))
        ActivitySeries.altitude: [
          for (final point in route) (at: point.at, value: point.altitude),
        ],
    },
    recovery: points(seriesRows['recovery']),
    route: route,
    intervals: [
      for (final interval in (row['laps'] as List?) ?? const [])
        if (interval is List && interval.length >= 3)
          ActivityInterval(
            isLap: interval[0] == 'lap',
            start: offset(interval[1]),
            end: offset(interval[2]),
          ),
    ],
    effort: number(row['effort']),
    estimatedEffort: number(row['estimatedEffort']),
    age: row['age'] as int?,
  );
}
