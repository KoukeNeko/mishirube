import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/health/health_source.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/activity/activity_detail_screen.dart';

import '../../support/harness.dart';

/// Apple Health holding one ride's detail.
class _Health implements HealthSource {
  _Health(this.detail);

  final ActivityDetail? detail;
  final asked = <String>[];

  @override
  String get name => 'Apple 健康';
  @override
  ChangeSource get changeSource => ChangeSource.healthKit;
  @override
  String get idPrefix => 'healthkit';
  @override
  Set<HealthDataKind> get kinds => HealthDataKind.values.toSet();
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<bool> requestAccess(Set<HealthDataKind> kinds) async => true;
  @override
  Future<Set<HealthDataKind>?> grantedKinds() async => null;
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
    DateTime to,
  ) async => const [];
  @override
  Future<ActivityDetail?> activityDetail(String platformId) async {
    asked.add(platformId);
    return detail;
  }
}

void main() {
  /// A ride north at 16 km/h, one point every 15 s for 12 minutes.
  final ride = parseActivityDetail({
    'activeMs': 12 * 60000,
    'device': 'Apple Watch',
    'place': '斗六市',
    'indoor': false,
    'temperature': 25.0,
    'humidity': 77.0,
    'elevationGain': 4.0,
    'figures': {'activeEnergy': 45.0, 'totalEnergy': 58.0, 'distance': 3200.0},
    'series': {
      'heartRate': [
        for (var i = 0; i <= 48; i++) [i * 15000, 130 + i],
      ],
      'speed': [
        for (var i = 0; i <= 48; i++) [i * 15000, 4.4],
      ],
      'recovery': [
        for (var i = 0; i <= 12; i++) [i * 15000, 170 - i * 2],
      ],
    },
    'route': [
      for (var i = 0; i <= 48; i++)
        [i * 66.7 / 111194.9, 0.0, 50.0 + i / 10, i * 15000, 4.4],
    ],
    'effort': 6,
    'age': 30,
  });

  Future<(AppStore, _Health)> storeWith(ActivityDetail? detail) async {
    final clock = FakeClock();
    final backend = Backend.inMemory(clock: clock.now);
    final health = _Health(detail);
    final store = AppStore(
      clock: clock.now,
      isOnboarded: true,
      backend: backend,
      health: health,
    );
    backend.storage.activities.add(
      ActivitySession(
        id: 'healthkit-workout-ABC',
        type: ActivityTypes.byId('cycling'),
        startedAt: clock.now().subtract(const Duration(hours: 2)),
        duration: const Duration(minutes: 12),
        distanceMeters: 3200,
      ),
      source: ChangeSource.healthKit,
    );
    return (store, health);
  }

  testWidgets('a ride read from Apple Health shows everything it recorded', (
    tester,
  ) async {
    final (store, health) = await storeWith(ride);
    await pumpScreen(
      tester,
      const ActivityDetailScreen(activityId: 'healthkit-workout-ABC'),
      store: store,
      window: const WindowCase('tall', Size(390, 3200)),
    );
    await tester.pump();

    expect(health.asked, ['ABC'], reason: 'the platform id, read once');
    for (final text in [
      '斗六市',
      '騎自行車（戶外）',
      '3.20 km',
      'Apple Watch · Apple 健康',
      '25°',
      '天氣',
      '77%',
      '濕度',
      '總能量',
      '平均速度',
      '平均心率',
      '分段 · 每 1 km',
      '區間 5',
      '運動後心率',
      '費力程度',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(find.text('編輯內容'), findsNothing, reason: 'the platform keeps it');
    expect(find.text('刪除這筆紀錄'), findsNothing);
    expect(find.text('3', skipOffstage: false), findsWidgets, reason: 'splits');
    await disposeTree(tester);
  });

  testWidgets('a session logged in the app shows only what was typed', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final (store, _) = await storeWith(null);
    final logged = store.backend.activity.log(
      type: ActivityTypes.byId('running'),
      startedAt: store.now().subtract(const Duration(hours: 1)),
      duration: const Duration(minutes: 30),
      distanceMeters: 5000,
    );
    await pumpScreen(
      tester,
      ActivityDetailScreen(activityId: logged.id),
      store: store,
    );
    await tester.pump();

    expect(find.text('平均配速'), findsOneWidget);
    expect(find.text('6:00 /km', findRichText: true), findsOneWidget);
    expect(find.text('心率'), findsNothing);
    expect(find.text('編輯內容'), findsOneWidget, reason: 'logged here');
    expect(find.text('刪除這筆紀錄'), findsOneWidget);
    await disposeTree(tester);
  });
}
