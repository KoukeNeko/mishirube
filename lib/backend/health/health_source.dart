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
  Future<List<HealthWeight>> weights(DateTime from, DateTime to);
  Future<List<HealthWaist>> waists(DateTime from, DateTime to);
  Future<List<HealthWorkout>> workouts(DateTime from, DateTime to);
  Future<List<HealthWater>> water(DateTime from, DateTime to);
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

  /// Health Connect has no waist circumference record.
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
    DateTime to,
  ) async =>
      await _channel.invokeListMethod<Map<Object?, Object?>>('read', {
        'kind': kind.name,
        'from': from.millisecondsSinceEpoch,
        'to': to.millisecondsSinceEpoch,
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
        ),
  ];

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
  Future<List<HealthWeight>> weights(DateTime from, DateTime to) async =>
      const [];
  @override
  Future<List<HealthWaist>> waists(DateTime from, DateTime to) async =>
      const [];
  @override
  Future<List<HealthWorkout>> workouts(DateTime from, DateTime to) async =>
      const [];
  @override
  Future<List<HealthWater>> water(DateTime from, DateTime to) async => const [];
}
