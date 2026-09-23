import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/engines/sleep_nights.dart';
import 'package:mishirube/backend/health/health_source.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/me/privacy_screen.dart';
import 'package:mishirube/features/nutrition/nutrition_view_model.dart';

import 'support/harness.dart';

/// A health platform as lists, and whether access was asked for.
class _FakeHealth implements HealthSource {
  _FakeHealth(
    this.samples, {
    this.weightRows = const [],
    this.waistRows = const [],
    this.workoutRows = const [],
    this.waterRows = const [],
    this.overnightRows = const [],
  });

  List<SleepSample> samples;
  List<HealthWeight> weightRows;
  List<HealthWaist> waistRows;
  List<HealthWorkout> workoutRows;
  List<HealthWater> waterRows;

  /// What is measured over every sleep asked about.
  List<OvernightReading> overnightRows;
  Set<HealthDataKind>? askedFor;

  /// What the platform says was allowed; null is Apple Health's silence.
  Set<HealthDataKind>? granted;

  /// Whether the platform opened the app to ask for its privacy page.
  bool asksForPrivacy = false;

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
  Future<bool> requestAccess(Set<HealthDataKind> kinds) async {
    askedFor = kinds;
    return true;
  }

  @override
  Future<Set<HealthDataKind>?> grantedKinds() async => granted;

  @override
  Future<void> onPrivacyRequest(void Function() show) async {
    if (asksForPrivacy) show();
  }

  @override
  Future<List<SleepSample>> sleepSamples(DateTime from, DateTime to) async =>
      samples;
  @override
  Future<List<List<OvernightReading>>> overnight(
    List<(DateTime, DateTime)> windows,
  ) async => [for (final _ in windows) overnightRows];
  @override
  Future<List<HealthWeight>> weights(DateTime from, DateTime to) async =>
      weightRows;
  @override
  Future<List<HealthWaist>> waists(DateTime from, DateTime to) async =>
      waistRows;
  @override
  Future<List<HealthWorkout>> workouts(DateTime from, DateTime to) async =>
      workoutRows;
  @override
  Future<List<HealthWater>> water(DateTime from, DateTime to) async =>
      waterRows;
}

SleepSample _asleep(DateTime start, DateTime end) =>
    SleepSample(start: start, end: end, stage: SleepStage.asleep);

void main() {
  group('nights from samples', () {
    test('a watch and a phone on the same night count once', () {
      final nights = nightsOf([
        _asleep(DateTime(2026, 9, 20, 23), DateTime(2026, 9, 21, 7)),
        _asleep(DateTime(2026, 9, 20, 23, 30), DateTime(2026, 9, 21, 6, 30)),
        SleepSample(
          start: DateTime(2026, 9, 20, 22, 30),
          end: DateTime(2026, 9, 21, 7, 15),
          stage: SleepStage.inBed,
        ),
      ]);
      final night = nights.single;
      expect(night.asleep, const Duration(hours: 8), reason: 'not 15 hours');
      expect(night.morning, DateTime(2026, 9, 21));
      expect(night.wokeAt, DateTime(2026, 9, 21, 7));
    });

    test('waking in the night leaves a gap, not a second night', () {
      final nights = nightsOf([
        _asleep(DateTime(2026, 9, 20, 23), DateTime(2026, 9, 21, 3)),
        SleepSample(
          start: DateTime(2026, 9, 21, 3),
          end: DateTime(2026, 9, 21, 3, 30),
          stage: SleepStage.awake,
        ),
        _asleep(DateTime(2026, 9, 21, 3, 30), DateTime(2026, 9, 21, 7)),
      ]);
      expect(nights.single.asleep, const Duration(hours: 7, minutes: 30));
    });

    test('bed after midnight belongs to that day; a nap is kept apart', () {
      final sleeps = nightsOf([
        _asleep(DateTime(2026, 9, 21, 1), DateTime(2026, 9, 21, 8)),
        _asleep(DateTime(2026, 9, 21, 14), DateTime(2026, 9, 21, 14, 30)),
        _asleep(DateTime(2026, 9, 21, 23), DateTime(2026, 9, 22, 6)),
      ]);
      expect(
        [for (final sleep in sleeps) (sleep.morning, sleep.kind)],
        [
          (DateTime(2026, 9, 21), SleepKind.night),
          (DateTime(2026, 9, 21), SleepKind.nap),
          (DateTime(2026, 9, 22), SleepKind.night),
        ],
      );
      expect(
        sleeps.first.asleep,
        const Duration(hours: 7),
        reason: 'the nap is not added to the night',
      );
    });

    test('a staged source is shown, not stitched to another', () {
      SleepSample stage(SleepStage stage, int from, int to) => SleepSample(
        start: DateTime(2026, 9, 21).add(Duration(minutes: from)),
        end: DateTime(2026, 9, 21).add(Duration(minutes: to)),
        stage: stage,
        source: 'com.apple.health',
        sourceName: 'Apple Watch',
      );
      final phone = SleepSample(
        start: DateTime(2026, 9, 20, 23),
        end: DateTime(2026, 9, 21, 8),
        stage: SleepStage.inBed,
        source: 'com.apple.iphone',
        sourceName: 'iPhone',
      );
      final ring = SleepSample(
        start: DateTime(2026, 9, 20, 23, 30),
        end: DateTime(2026, 9, 21, 7, 30),
        stage: SleepStage.asleep,
        source: 'com.ouraring',
        sourceName: 'Oura',
      );
      final watch = [
        stage(SleepStage.core, 0, 90),
        stage(SleepStage.deep, 90, 150),
        stage(SleepStage.awake, 150, 160),
        stage(SleepStage.rem, 160, 400),
      ];
      final night = nightsOf([phone, ring, ...watch]).single;

      expect(night.summary.sourceName, 'Apple Watch');
      expect(night.summary.hasStages, isTrue);
      expect(
        night.asleep,
        const Duration(minutes: 390),
        reason: "the watch's time asleep, awake left out, the ring not added",
      );
      expect(stageTotals(stagesOf(night.samples, night.summary.source)), {
        SleepStage.awake: const Duration(minutes: 10),
        SleepStage.core: const Duration(minutes: 90),
        SleepStage.deep: const Duration(minutes: 60),
        SleepStage.rem: const Duration(minutes: 240),
      });
      expect(
        summarize(night.samples, source: 'com.ouraring')!.length,
        const Duration(hours: 8),
        reason: 'another source can still be shown',
      );
    });

    test('in bed and nothing more is time in bed, not time asleep', () {
      final night = nightsOf([
        SleepSample(
          start: DateTime(2026, 9, 20, 23),
          end: DateTime(2026, 9, 21, 7),
          stage: SleepStage.inBed,
          source: 'com.apple.iphone',
        ),
      ]).single;
      expect(night.summary.measure, SleepMeasure.inBed);
      expect(night.asleep, const Duration(hours: 8));
      expect(night.summary.hasStages, isFalse);
    });
  });

  group('importing from Apple Health', () {
    final clock = FakeClock();

    AppStore storeWith(_FakeHealth health) => AppStore(
      clock: clock.now,
      isOnboarded: true,
      backend: Backend.inMemory(clock: clock.now),
      health: health,
    );

    final lastNight = _asleep(
      clock.now().subtract(const Duration(hours: 9)),
      clock.now().subtract(const Duration(hours: 1)),
    );

    List<SleepEntry> imported(AppStore store) => [
      for (final night in store.backend.journal.recentSleep(
        const Duration(days: 28),
      ))
        if (store.backend.journal.sourceOf(night.id) == ChangeSource.healthKit)
          night,
    ];

    test(
      'connecting asks, reads, and marks where the nights came from',
      () async {
        final health = _FakeHealth([lastNight]);
        final store = storeWith(health);

        final result = await store.connectHealth();

        expect(health.askedFor, HealthDataKind.values.toSet());
        expect(result!.added[HealthDataKind.sleep], 1);
        expect(store.isHealthConnected, isTrue);
        expect(imported(store).single.duration, const Duration(hours: 8));
      },
    );

    test('reading again updates a night instead of adding it twice', () async {
      final health = _FakeHealth([lastNight]);
      final store = storeWith(health);
      await store.connectHealth();

      expect((await store.syncHealth())!.added[HealthDataKind.sleep], 0);
      expect(imported(store), hasLength(1));

      // The watch synced late: the night is longer now.
      health.samples = [
        lastNight,
        _asleep(lastNight.end, lastNight.end.add(const Duration(minutes: 40))),
      ];
      expect((await store.syncHealth())!.updated, 1);
      expect(
        imported(store).single.duration,
        const Duration(hours: 8, minutes: 40),
      );
    });

    test(
      'a night the user logged is theirs, and a deleted one stays gone',
      () async {
        final health = _FakeHealth([lastNight]);
        final store = storeWith(health);
        store.backend.journal.recordSleep(
          const Duration(hours: 6),
          at: lastNight.end,
        );

        final first = await store.connectHealth();
        expect(first!.skipped, 1, reason: 'the hand-logged night is kept');
        expect(imported(store), isEmpty);

        // Without the hand-logged night, it comes in; deleted, it stays out.
        final other = storeWith(_FakeHealth([lastNight]));
        await other.connectHealth();
        final night = imported(other).single;
        other.backend.journal.delete(night.id);
        await other.syncHealth();
        expect(imported(other), isEmpty);
      },
    );

    test('weight, waist, workouts and water come in once each', () async {
      final at = clock.now().subtract(const Duration(hours: 3));
      final health = _FakeHealth(
        const [],
        weightRows: [HealthWeight(id: 'w1', at: at, kg: 71.4)],
        waistRows: [HealthWaist(id: 'c1', at: at, cm: 80.5)],
        workoutRows: [
          HealthWorkout(
            id: 'r1',
            start: at,
            end: at.add(const Duration(minutes: 30)),
            activity: 'running',
            nativeType: 'HKWorkoutActivityType.37',
            distanceMeters: 5000,
          ),
        ],
        waterRows: [HealthWater(id: 'h1', at: at, ml: 300)],
      );
      final store = storeWith(health);
      final nutrition = NutritionViewModel(store.backend);
      addTearDown(nutrition.dispose);
      final waterBefore = nutrition.todayWater.millilitres;

      final first = await store.connectHealth();
      expect(first!.added, {
        HealthDataKind.sleep: 0,
        HealthDataKind.weight: 1,
        HealthDataKind.waist: 1,
        HealthDataKind.workouts: 1,
        HealthDataKind.water: 1,
        HealthDataKind.overnight: 0,
      });
      expect(
        store.backend.journal
            .recentWeights(const Duration(days: 28))
            .last
            .weightKg,
        71.4,
      );
      final run = store
          .activitiesOn(at)
          .firstWhere((session) => session.id == 'healthkit-workout-r1');
      expect(run.type.id, 'running');
      expect(run.distanceMeters, 5000);
      expect(run.duration, const Duration(minutes: 30));
      expect(
        nutrition.todayWater.millilitres,
        waterBefore + 300,
        reason: 'water read in shows on today at once',
      );

      final again = await store.syncHealth();
      expect(
        again!.foundNothing,
        isTrue,
        reason: 'the same records read twice are not added twice',
      );
    });

    test('a kind the user did not allow is not read, and is named', () async {
      final at = clock.now().subtract(const Duration(hours: 3));
      final health = _FakeHealth(
        [lastNight],
        weightRows: [HealthWeight(id: 'w1', at: at, kg: 71.4)],
      )..granted = {HealthDataKind.sleep};
      final store = storeWith(health);
      final weighings = store.backend.journal
          .recentWeights(const Duration(days: 28))
          .length;

      final result = await store.connectHealth();

      expect(result!.added.keys, [HealthDataKind.sleep]);
      expect(
        store.backend.journal.recentWeights(const Duration(days: 28)),
        hasLength(weighings),
        reason: 'not read',
      );
      expect(result.denied, {
        HealthDataKind.weight,
        HealthDataKind.waist,
        HealthDataKind.workouts,
        HealthDataKind.water,
        HealthDataKind.overnight,
      });
      expect(await store.healthGrantedKinds(), {HealthDataKind.sleep});
    });

    test('a platform that will not say is read in full', () async {
      final health = _FakeHealth([lastNight]);
      final store = storeWith(health);

      final result = await store.connectHealth();

      expect(result!.denied, isNull, reason: 'unknown is not "none denied"');
      expect(result.added[HealthDataKind.sleep], 1);
      expect(await store.healthGrantedKinds(), isNull);
    });

    testWidgets('the platform asking for the privacy page opens it', (
      tester,
    ) async {
      final store = storeWith(_FakeHealth(const [])..asksForPrivacy = true);
      await tester.pumpWidget(MishirubeApp(store: store));
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyScreen), findsOneWidget);
      expect(find.text('只讀，不寫入'), findsOneWidget);
      await disposeTree(tester);
    });

    test('a sleep keeps its stages and what was measured over it', () async {
      final start = clock.now().subtract(const Duration(hours: 9));
      SleepSample stage(SleepStage stage, int from, int to, String source) =>
          SleepSample(
            start: start.add(Duration(minutes: from)),
            end: start.add(Duration(minutes: to)),
            stage: stage,
            source: source,
            sourceName: source == 'watch' ? 'Apple Watch' : 'Oura',
          );
      const heart = OvernightReading(
        measure: OvernightMeasure.heartRate,
        minimum: 52,
        maximum: 67,
        average: 58,
        count: 120,
      );
      final health = _FakeHealth(
        [
          stage(SleepStage.core, 0, 200, 'watch'),
          stage(SleepStage.deep, 200, 300, 'watch'),
          stage(SleepStage.rem, 300, 460, 'watch'),
          stage(SleepStage.asleep, 10, 470, 'ring'),
        ],
        overnightRows: [heart],
      );
      final store = storeWith(health);
      await store.connectHealth();

      final night = store.backend.sleep.day(clock.now()).single;
      expect(night.entry.sourceName, 'Apple Watch');
      expect(night.entry.duration, const Duration(minutes: 460));
      expect(night.hasStages, isTrue);
      expect(night.readings, [heart]);
      expect(night.sources.map((source) => source.sourceName), [
        'Apple Watch',
        'Oura',
      ]);

      // Picked by hand, the ring stays picked when the platform is read
      // again.
      store.backend.sleep.chooseSource(night.entry.id, 'ring');
      await store.syncHealth();
      final shown = store.backend.sleep.day(clock.now()).single;
      expect(shown.entry.sourceName, 'Oura');
      expect(shown.entry.duration, const Duration(minutes: 460));
      expect(shown.hasStages, isFalse, reason: 'the ring did not stage it');
    });

    test('a nap comes in as its own record', () async {
      final wake = clock.now().subtract(const Duration(hours: 6));
      final health = _FakeHealth([
        _asleep(wake.subtract(const Duration(hours: 8)), wake),
        _asleep(
          wake.add(const Duration(hours: 4)),
          wake.add(const Duration(hours: 4, minutes: 30)),
        ),
      ]);
      final store = storeWith(health);
      await store.connectHealth();

      final kinds = [
        for (final sleep in store.backend.sleep.day(wake)) sleep.entry.kind,
      ];
      expect(kinds, [SleepKind.night, SleepKind.nap]);
    });

    test('nothing is read until the user connects', () async {
      final store = storeWith(_FakeHealth([lastNight]));
      expect(await store.syncHealth(), isNull);
      expect(imported(store), isEmpty);
    });
  });
}
