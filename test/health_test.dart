import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/l10n/l10n.dart';
import 'package:mishirube/app/app.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/application/health_service.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/engines/sleep_nights.dart';
import 'package:mishirube/backend/health/health_source.dart';
import 'package:mishirube/backend/import_export/canonical_archive.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/backend/storage/journal_repository.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/journal/journal_detail_screen.dart';
import 'package:mishirube/features/me/privacy_screen.dart';
import 'package:mishirube/features/sleep/sleep_screen.dart';
import 'package:mishirube/features/nutrition/nutrition_view_model.dart';
import 'package:mishirube/features/today/today_screen.dart';
import 'package:mishirube/features/today/today_view_model.dart';

import 'support/harness.dart';

/// A health platform as lists, and whether access was asked for.
class _FakeHealth implements HealthSource {
  _FakeHealth(
    this.samples, {
    this.weightRows = const [],
    this.waistRows = const [],
    this.bodyRows = const [],
    this.workoutRows = const [],
    this.waterRows = const [],
    this.foodRows = const [],
    this.moodRows = const [],
    this.overnightRows = const [],
    this.activityRows = const [],
  });

  List<SleepSample> samples;
  List<HealthWeight> weightRows;
  List<HealthWaist> waistRows;
  List<HealthBodyReading> bodyRows;
  List<HealthWorkout> workoutRows;
  List<HealthWater> waterRows;
  List<HealthFood> foodRows;
  List<HealthMood> moodRows;
  List<ActivitySample> activityRows;

  /// What is measured over every sleep asked about.
  List<OvernightReading> overnightRows;
  Set<HealthDataKind>? askedFor;

  /// What the platform says was allowed; null is Apple Health's silence.
  Set<HealthDataKind>? granted;

  /// Whether the platform opened the app to ask for its privacy page.
  bool asksForPrivacy = false;

  @override
  String nameIn(AppLocalizations l10n) => l10n.appleHealth;
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

  /// Holds every read of sleep until completed, for a read that takes a
  /// while.
  Completer<void>? gate;

  /// Makes every read of sleep fail, as a platform that is unavailable.
  bool fails = false;

  @override
  Future<List<SleepSample>> sleepSamples(DateTime from, DateTime to) async {
    readFrom.add(to.difference(from));
    await gate?.future;
    if (fails) throw Exception('unavailable');
    return [
      for (final sample in samples)
        if (_within(sample.start, from, to)) sample,
    ];
  }

  /// A platform answers a read with what lies in it, and nothing else.
  static bool _within(DateTime at, DateTime from, DateTime to) =>
      !at.isBefore(from) && at.isBefore(to);

  /// How far back each read of sleep reached.
  final readFrom = <Duration>[];
  @override
  Future<List<List<OvernightReading>>> overnight(
    List<(DateTime, DateTime)> windows,
  ) async => [for (final _ in windows) overnightRows];
  @override
  Future<List<HealthWeight>> weights(DateTime from, DateTime to) async => [
    for (final row in weightRows)
      if (_within(row.at, from, to)) row,
  ];
  @override
  Future<List<HealthWaist>> waists(DateTime from, DateTime to) async => [
    for (final row in waistRows)
      if (_within(row.at, from, to)) row,
  ];
  @override
  Future<List<HealthBodyReading>> bodyReadings(
    DateTime from,
    DateTime to,
  ) async => [
    for (final row in bodyRows)
      if (_within(row.at, from, to)) row,
  ];
  @override
  Future<List<HealthWorkout>> workouts(DateTime from, DateTime to) async => [
    for (final row in workoutRows)
      if (_within(row.start, from, to)) row,
  ];
  @override
  Future<List<HealthWater>> water(DateTime from, DateTime to) async => [
    for (final row in waterRows)
      if (_within(row.at, from, to)) row,
  ];
  @override
  Future<List<HealthFood>> foods(DateTime from, DateTime to) async => [
    for (final row in foodRows)
      if (_within(row.at, from, to)) row,
  ];
  @override
  Future<List<HealthMood>> moods(DateTime from, DateTime to) async => [
    for (final row in moodRows)
      if (_within(row.at, from, to)) row,
  ];

  /// Everything written to it, in order.
  final written = <HealthWrite>[];
  @override
  Future<void> write(List<HealthWrite> writes) async => written.addAll(writes);
  @override
  Future<List<ActivitySample>> activitySamples(
    DateTime from,
    DateTime to, {
    bool isHourly = true,
  }) async => [
    for (final row in activityRows)
      if (_within(row.start, from, to)) row,
  ];

  @override
  Future<ActivityDetail?> activityDetail(String platformId) async => null;

  @override
  Future<Map<OvernightMeasure, List<(DateTime, double)>>> overnightSeries(
    DateTime from,
    DateTime to,
  ) async => const {};
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

    test('a day whose longest sleep is under three hours has no night', () {
      List<SleepKind> kindsOf(Duration length) => [
        for (final sleep in nightsOf([
          _asleep(
            DateTime(2026, 9, 21, 13),
            DateTime(2026, 9, 21, 13).add(length),
          ),
        ]))
          sleep.kind,
      ];
      expect(kindsOf(const Duration(hours: 2, minutes: 59)), [SleepKind.nap]);
      expect(kindsOf(const Duration(hours: 3)), [SleepKind.night]);
    });

    test('an evening nap is a nap before its night arrives', () {
      // Starting after 18:00 it belongs to the next morning's day, which
      // has no night yet: it must not read as last night.
      final nap = nightsOf([
        _asleep(DateTime(2026, 9, 21, 19), DateTime(2026, 9, 21, 20)),
      ]).single;
      expect(nap.kind, SleepKind.nap);
      expect(nap.morning, DateTime(2026, 9, 22));

      final both = nightsOf([
        _asleep(DateTime(2026, 9, 21, 19), DateTime(2026, 9, 21, 20)),
        _asleep(DateTime(2026, 9, 21, 23), DateTime(2026, 9, 22, 7)),
      ]);
      expect(
        [for (final sleep in both) sleep.kind],
        [SleepKind.nap, SleepKind.night],
      );
    });

    test('a sleep under twenty minutes is dropped, twenty is a nap', () {
      final sleeps = nightsOf([
        _asleep(DateTime(2026, 9, 20, 23), DateTime(2026, 9, 21, 7)),
        _asleep(DateTime(2026, 9, 21, 12), DateTime(2026, 9, 21, 12, 19)),
        _asleep(DateTime(2026, 9, 21, 15), DateTime(2026, 9, 21, 15, 20)),
      ]);
      expect(
        [for (final sleep in sleeps) sleep.kind],
        [SleepKind.night, SleepKind.nap],
      );
      expect(sleeps.last.asleep, const Duration(minutes: 20));
      expect(
        nightsOf([
          _asleep(DateTime(2026, 9, 21, 12), DateTime(2026, 9, 21, 12, 10)),
        ]),
        isEmpty,
        reason: 'a day with only a short rest has no sleep at all',
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

    test('activity comes in as the platform counted it, and a re-read '
        'changes only what moved', () async {
      final today = clock.now();
      DateTime hour(int h) => DateTime(today.year, today.month, today.day, h);
      ActivitySample steps(int h, double value) => ActivitySample(
        metric: ActivityMetric.steps,
        start: hour(h),
        end: hour(h + 1),
        value: value,
      );
      final health = _FakeHealth(
        const [],
        activityRows: [
          steps(8, 500),
          steps(9, 700),
          ActivitySample(
            metric: ActivityMetric.restingHeartRate,
            start: hour(0),
            end: hour(0).add(const Duration(days: 1)),
            value: 61,
          ),
        ],
      );
      final store = storeWith(health);

      final first = await store.connectHealth();
      expect(first!.added[HealthDataKind.activity], 3);
      expect(store.backend.activity.dayTotals(today), {
        ActivityMetric.steps: 1200,
        ActivityMetric.restingHeartRate: 61,
      });

      final again = await store.syncHealth();
      expect(again!.added[HealthDataKind.activity], 0, reason: 'unchanged');

      health.activityRows = [steps(8, 500), steps(9, 900)];
      final moved = await store.syncHealth();
      expect(moved!.added[HealthDataKind.activity], 1);
      expect(
        store.backend.activity.dayTotals(today)[ActivityMetric.steps],
        1400,
      );
      expect(
        store.backend.activity.hourly(ActivityMetric.steps, today)![9],
        900,
      );
    });

    test('a kind added in an update is asked for once', () async {
      final health = _FakeHealth(const []);
      final store = storeWith(health);
      await store.connectHealth();
      // Connected before activity existed.
      store.backend.db.setSetting('health.asked_kinds', 'sleep,weight');
      health.askedFor = null;

      await store.syncHealth();
      expect(health.askedFor, contains(HealthDataKind.activity));

      health.askedFor = null;
      await store.syncHealth();
      expect(health.askedFor, isNull);

      // Every kind asked for, but before workouts also read routes.
      store.backend.db.setSetting('health.asked_version', '1');
      await store.syncHealth();
      expect(health.askedFor, isNotNull, reason: 'asked again, once');
    });

    test('a store in a file is written on another isolate, and the '
        'screens hear of it', () async {
      final directory = Directory.systemTemp.createTempSync('mishirube_health');
      addTearDown(() => directory.deleteSync(recursive: true));
      final backend = Backend(
        AppDatabase.open('${directory.path}/store.sqlite3', clock: clock.now),
      );
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
        health: _FakeHealth([lastNight]),
      );
      var changes = 0;
      backend.db.changes.addListener(() => changes++);

      final first = await store.connectHealth();
      expect(first!.added[HealthDataKind.sleep], 1);
      expect(imported(store), hasLength(1), reason: 'read back here');
      expect(changes, greaterThan(0), reason: 'the screens are told');

      final again = await store.syncHealth();
      expect(again!.added[HealthDataKind.sleep], 0, reason: 'not twice');
    });

    test('coming back to the front mid-sync joins the sync, once', () async {
      final health = _FakeHealth([lastNight]);
      final store = storeWith(health);
      await store.connectHealth();
      health.readFrom.clear();

      await Future.wait([
        store.syncHealthInBackground(),
        store.syncHealthInBackground(),
      ]);
      final joined = health.readFrom.length;
      health.readFrom.clear();
      await store.syncHealthInBackground();

      expect(joined, greaterThan(0));
      expect(joined, health.readFrom.length, reason: 'read once, not twice');
      expect(store.healthSyncFailed, isFalse);
    });

    test('the first read reaches back to 2014 a year at a time, later ones '
        'a month', () async {
      final health = _FakeHealth([lastNight]);
      final store = storeWith(health);
      await store.connectHealth();
      final firstRead = [...health.readFrom];
      await store.syncHealth();

      expect(
        firstRead.fold(Duration.zero, (sum, read) => sum + read),
        clock.now().difference(HealthService.earliest),
        reason: 'everything the platform can hold, without a gap',
      );
      expect(
        firstRead.every((read) => read <= const Duration(days: 366)),
        isTrue,
        reason: 'a year at a time',
      );
      expect(health.readFrom.last, HealthService.window);
    });

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

    test('weight, waist, body, workouts and water come in once each', () async {
      final at = clock.now().subtract(const Duration(hours: 3));
      final health = _FakeHealth(
        const [],
        weightRows: [HealthWeight(id: 'w1', at: at, kg: 71.4)],
        waistRows: [HealthWaist(id: 'c1', at: at, cm: 80.5)],
        bodyRows: [
          HealthBodyReading(
            id: 'b1',
            at: at,
            metric: BodyMetric.height,
            value: 175,
          ),
          HealthBodyReading(
            id: 'b2',
            at: at,
            metric: BodyMetric.bodyFat,
            value: 18.2,
          ),
        ],
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
        HealthDataKind.body: 2,
        HealthDataKind.workouts: 1,
        HealthDataKind.water: 1,
        HealthDataKind.nutrition: 0,
        HealthDataKind.mood: 0,
        HealthDataKind.overnight: 0,
        HealthDataKind.activity: 0,
      });
      expect(
        store.backend.journal
            .recentWeights(const Duration(days: 28))
            .last
            .weightKg,
        71.4,
      );
      expect(
        store.backend.journal.latestBodyReadings()[BodyMetric.bodyFat]?.value,
        18.2,
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

    test('food and moods another app logged come in once each', () async {
      final at = clock.now().subtract(const Duration(hours: 3));
      final health = _FakeHealth(
        const [],
        foodRows: [
          HealthFood(
            id: 'f1',
            at: at,
            sourceName: 'MyFitnessPal',
            name: '燕麥粥',
            mealType: MealType.breakfast,
            kcal: 310.4,
            proteinGrams: 11.6,
            carbGrams: 52.2,
            fatGrams: 6.1,
            fibreGrams: 7.8,
            nutrients: const {Nutrient.sodium: 120, Nutrient.sugar: 9.5},
          ),
          HealthFood(
            id: 'f2',
            at: at,
            sourceName: 'Caffeine Tracker',
            nutrients: const {Nutrient.caffeine: 95},
          ),
        ],
        moodRows: [
          HealthMood(id: 'm1', at: at, valence: 0.6),
          HealthMood(id: 'm2', at: at, valence: -1),
        ],
      );
      final store = storeWith(health);

      final first = await store.connectHealth();
      expect(first!.added[HealthDataKind.nutrition], 2);
      expect(first.added[HealthDataKind.mood], 2);

      final meals = {
        for (final meal in store.backend.nutrition.mealsOn(at))
          if (meal.id.startsWith('healthkit-food-')) meal.id: meal,
      };
      final oats = meals['healthkit-food-f1']!;
      expect(oats.name, '燕麥粥');
      expect(oats.qualityTag, 'MyFitnessPal', reason: 'marked with its app');
      expect(oats.mealType, MealType.breakfast);
      expect(
        [oats.kcal, oats.proteinGrams, oats.carbGrams, oats.fatGrams],
        [310.4, 11.6, 52.2, 6.1],
        reason: 'as the other app wrote them',
      );
      expect(oats.fibreGrams, 7.8);
      expect(oats.nutrients, {Nutrient.sodium: 120, Nutrient.sugar: 9.5});
      final coffee = meals['healthkit-food-f2']!;
      expect(coffee.name, '咖啡因', reason: 'caffeine alone, named for it');
      expect(coffee.kind, ConsumptionKind.beverage);
      expect(coffee.kcal, isNull, reason: 'not recorded is not zero');

      final moods = store.backend.journal
          .recentWellness(const Duration(days: 1))
          .where((entry) => entry.id.startsWith('healthkit-mood-'));
      expect(
        {for (final mood in moods) mood.id: mood.score},
        {'healthkit-mood-m1': 4, 'healthkit-mood-m2': 1},
      );

      final again = await store.syncHealth();
      expect(again!.foundNothing, isTrue);
    });

    test('what is logged in the app is written, and follows edits', () async {
      // The group's clock is shared: put it back for the tests after.
      final started = clock.current;
      addTearDown(() => clock.current = started);
      final health = _FakeHealth(
        const [],
        weightRows: [
          HealthWeight(
            id: 'w1',
            at: clock.now().subtract(const Duration(hours: 5)),
            kg: 70,
          ),
        ],
      );
      final store = storeWith(health);
      await store.connectHealth();
      expect(
        health.written,
        isEmpty,
        reason: 'the demo content and what was read in are not written',
      );

      clock.advance(const Duration(minutes: 1));
      final journal = store.backend.journal;
      final weight = journal.recordWeight(71.2);
      journal.recordWellness(WellnessKind.mood, 5);
      journal.recordWellness(WellnessKind.energy, 2);
      final water = store.backend.nutrition.logWater(250);
      store
        ..startWorkout()
        ..beginWorkout();
      clock.advance(const Duration(minutes: 40));
      store.finishWorkout();
      await store.syncHealth();

      Map<HealthWriteKind, HealthWrite> byKind() => {
        for (final write in health.written) write.kind: write,
      };
      expect(byKind().keys, {
        HealthWriteKind.weight,
        HealthWriteKind.mood,
        HealthWriteKind.water,
        HealthWriteKind.workout,
      }, reason: 'energy has no place on a platform');
      final workout = byKind()[HealthWriteKind.workout]!;
      expect(workout.values['activity'], 'strength');
      expect(
        (workout.values['end']! as int) - (workout.values['start']! as int),
        const Duration(minutes: 40).inMilliseconds,
      );
      expect(byKind()[HealthWriteKind.weight]!.id, weight.id);
      expect(byKind()[HealthWriteKind.weight]!.values['kg'], 71.2);
      expect(byKind()[HealthWriteKind.mood]!.values['valence'], 1.0);
      expect(byKind()[HealthWriteKind.water]!.values['ml'], 250);
      final firstVersion = byKind()[HealthWriteKind.weight]!.version;

      health.written.clear();
      await store.syncHealth();
      expect(health.written, isEmpty, reason: 'nothing changed since');

      clock.advance(const Duration(minutes: 1));
      journal.updateWeight(
        BodyWeight(id: weight.id, measuredAt: weight.measuredAt, weightKg: 71),
      );
      store.backend.nutrition.deleteMeals([water.id]);
      await store.syncHealth();
      final edited = byKind()[HealthWriteKind.weight]!;
      expect(edited.values['kg'], 71.0);
      expect(edited.version, greaterThan(firstVersion));
      expect(
        health.written.where((write) => write.isDelete).map((w) => w.id),
        everyElement(water.id),
        reason: 'a deleted glass is removed wherever it was written',
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
        HealthDataKind.body,
        HealthDataKind.workouts,
        HealthDataKind.water,
        HealthDataKind.nutrition,
        HealthDataKind.mood,
        HealthDataKind.overnight,
        HealthDataKind.activity,
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

    testWidgets('Today says it is reading only when a read takes a while', (
      tester,
    ) async {
      final health = _FakeHealth([lastNight]);
      final store = storeWith(health);
      await store.connectHealth();
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(MishirubeApp(store: store));
      await tester.pump();
      final reading = find.bySemanticsLabel('讀取中…');

      health.gate = Completer<void>();
      store.syncHealthInBackground();
      await tester.pump(const Duration(seconds: 1));
      expect(reading, findsNothing, reason: 'a quick read is quiet');
      await tester.pump(const Duration(seconds: 1));
      expect(reading, findsOneWidget);
      expect(
        find.text('讀取中…'),
        findsNothing,
        reason: 'a spinner, not a labelled pill',
      );

      health.gate!.complete();
      await tester.pumpAndSettle();
      expect(reading, findsNothing, reason: 'done says nothing');
      expect(find.text('讀取失敗'), findsNothing);
      semantics.dispose();
      await disposeTree(tester);
    });

    testWidgets('a failed read says so on Today, and a tap reads again', (
      tester,
    ) async {
      final health = _FakeHealth([lastNight]);
      final store = storeWith(health);
      await store.connectHealth();
      await tester.pumpWidget(MishirubeApp(store: store));
      await tester.pump();

      final failed = find.byTooltip('讀取失敗 · 重試');
      health.fails = true;
      await store.syncHealthInBackground();
      await tester.pump();
      expect(failed, findsOneWidget);
      expect(find.text('讀取失敗'), findsNothing, reason: 'an icon, no label');

      health.fails = false;
      await tester.tap(failed);
      await tester.pumpAndSettle();
      expect(store.healthSyncFailed, isFalse);
      expect(failed, findsNothing);
      await disposeTree(tester);
    });

    testWidgets('Today is not rebuilt as the dock moves the page padding', (
      tester,
    ) async {
      final store = storeWith(_FakeHealth([lastNight]));
      await store.connectHealth();
      var bottom = 0.0;
      late StateSetter setBottom;
      await pumpScreen(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            setBottom = setState;
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(padding: EdgeInsets.only(bottom: bottom)),
              child: const TodayScreen(),
            );
          },
        ),
        store: store,
      );
      var rebuilds = 0;
      final previous = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, _) {
        // The builder that runs the page, and its queries: not the
        // header's, which follows the padding as it should.
        if (element.widget case ListenableBuilder(
          listenable: TodayViewModel(),
        )) {
          rebuilds++;
        }
      };
      addTearDown(() => debugOnRebuildDirtyWidget = previous);

      // The dock shrinking and growing, as it does through a scroll.
      for (var frame = 1; frame <= 10; frame++) {
        setBottom(() => bottom = frame * 4.0);
        await tester.pump();
      }

      expect(
        rebuilds,
        0,
        reason: 'every rebuild runs the page\'s queries on the main thread',
      );
      await disposeTree(tester);
    });

    testWidgets('pulling Today down reads again', (tester) async {
      final health = _FakeHealth([lastNight]);
      final store = storeWith(health);
      await store.connectHealth();
      await tester.pumpWidget(MishirubeApp(store: store));
      await tester.pump();
      health.readFrom.clear();

      await tester.fling(
        find.byType(CustomScrollView).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(health.readFrom, isNotEmpty);
      await disposeTree(tester);
    });

    testWidgets('the platform asking for the privacy page opens it', (
      tester,
    ) async {
      final store = storeWith(_FakeHealth(const [])..asksForPrivacy = true);
      await tester.pumpWidget(MishirubeApp(store: store));
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyScreen), findsOneWidget);
      await tester.scrollUntilVisible(find.text('讀取與寫入'), 200);
      expect(find.text('讀取與寫入'), findsOneWidget);
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
  group('a sleep the user calls a nap', () {
    final clock = FakeClock();

    AppStore storeWith(_FakeHealth health) => AppStore(
      clock: clock.now,
      isOnboarded: true,
      backend: Backend.inMemory(clock: clock.now),
      health: health,
    );

    // This morning's night and an afternoon nap, on one day.
    final woke = DateTime(2026, 9, 19, 7);
    final napStart = DateTime(2026, 9, 19, 14);
    List<SleepSample> day() => [
      _asleep(woke.subtract(const Duration(hours: 8)), woke),
      _asleep(napStart, napStart.add(const Duration(minutes: 40))),
    ];

    SleepEntry nightOf(AppStore store) => store.backend.sleep
        .day(woke)
        .firstWhere((record) => record.entry.kind == SleepKind.night)
        .entry;

    Map<SleepKind, int> kinds(AppStore store) => {
      for (final kind in SleepKind.values)
        kind: store.backend.sleep
            .day(woke)
            .where((record) => record.entry.kind == kind)
            .length,
    };

    test('beats the rules, survives a re-read and is not an update', () async {
      final store = storeWith(_FakeHealth(day()));
      await store.connectHealth();
      final night = nightOf(store);

      store.backend.journal.setSleepKind(night.id, SleepKind.nap);
      expect(kinds(store), {SleepKind.night: 0, SleepKind.nap: 2});

      final again = await store.syncHealth();
      expect(kinds(store), {SleepKind.night: 0, SleepKind.nap: 2});
      expect(again!.updated, 0, reason: 'the data did not move');
      expect(again.foundNothing, isTrue);

      // A short sleep the user calls the night is the night.
      final nap = store.backend.sleep
          .day(woke)
          .firstWhere((record) => record.entry.duration.inMinutes == 40);
      store.backend.journal.setSleepKind(nap.entry.id, SleepKind.night);
      await store.syncHealth();
      expect(nightOf(store).id, nap.entry.id);
      expect(nightOf(store).duration, const Duration(minutes: 40));
    });

    test('saying what the data says clears the override', () async {
      final store = storeWith(_FakeHealth(day()));
      await store.connectHealth();
      final night = nightOf(store);
      final journal = store.backend.journal;
      String? override() =>
          store.backend.db.select(
                'SELECT kind_override FROM sleep_entries WHERE id = ?',
                [night.id],
              ).single['kind_override']
              as String?;

      journal.setSleepKind(night.id, SleepKind.nap);
      expect(override(), 'nap');
      journal.setSleepKind(night.id, SleepKind.night);
      expect(override(), isNull);
      expect(
        journal.setSleepKind(night.id, SleepKind.night),
        isEmpty,
        reason: 'nothing to change, nothing to undo',
      );
    });

    test('making a nap the night turns the old night into a nap, and one '
        'undo puts both back', () async {
      final store = storeWith(_FakeHealth(day()));
      await store.connectHealth();
      final night = nightOf(store);
      final nap = store.backend.sleep
          .day(woke)
          .firstWhere((record) => record.entry.kind == SleepKind.nap)
          .entry;

      final undo = store.backend.journal.setSleepKind(nap.id, SleepKind.night);
      expect(nightOf(store).id, nap.id);
      expect(kinds(store), {SleepKind.night: 1, SleepKind.nap: 1});
      expect(
        store.backend.db.select(
          'SELECT payload FROM audit_events WHERE entity_id = ? '
          "AND action = 'edit'",
          [night.id],
        ).single['payload'],
        contains(nap.id),
        reason: 'the swap says what it was swapped with',
      );

      store.backend.journal.restoreSleepKinds(undo);
      expect(nightOf(store).id, night.id);
      expect(kinds(store), {SleepKind.night: 1, SleepKind.nap: 1});
    });

    test('a typed-in sleep takes the switch too, and the override '
        'round-trips through the archive', () {
      final backend = Backend.inMemory(clock: clock.now);
      addTearDown(backend.close);
      final night = backend.journal.recordSleep(
        const Duration(hours: 7),
        at: woke,
        startedAt: woke.subtract(const Duration(hours: 7)),
      );
      backend.journal.setSleepKind(night.id, SleepKind.nap);
      expect(
        backend.sleep.nights(woke, woke.add(const Duration(days: 1))),
        isEmpty,
      );

      final archive = exportArchive(backend.db);
      final restored = Backend.inMemory(clock: clock.now);
      addTearDown(restored.close);
      restoreArchive(restored.db, jsonDecode(encodeArchive(archive)));
      expect(exportArchive(restored.db), archive);
      expect(
        (restored.journal.entry(night.id)! as SleepEntry).kind,
        SleepKind.nap,
      );
    });

    test('editing a sleep keeps what the data said, not what the user set', () {
      final backend = Backend.inMemory(clock: clock.now);
      addTearDown(backend.close);
      final night = backend.journal.recordSleep(
        const Duration(hours: 7),
        at: woke,
      );
      backend.journal.setSleepKind(night.id, SleepKind.nap);
      final edited = backend.journal.entry(night.id)! as SleepEntry;

      backend.journal.updateSleep(
        SleepEntry(
          id: edited.id,
          sleptAt: edited.sleptAt,
          duration: edited.duration,
          score: 4,
          kind: edited.kind,
        ),
      );
      // Calling it a night again is what the data says: no override left.
      backend.journal.setSleepKind(night.id, SleepKind.night);
      expect(
        (backend.journal.entry(night.id)! as SleepEntry).kind,
        SleepKind.night,
      );
    });
  });

  group('sleeps a platform stopped producing', () {
    final clock = FakeClock();
    final now = clock.now();

    AppStore storeWith(_FakeHealth health) => AppStore(
      clock: clock.now,
      isOnboarded: true,
      backend: Backend.inMemory(clock: clock.now),
      health: health,
    );

    DateTime morning(int daysAgo) =>
        DateTime(now.year, now.month, now.day - daysAgo, 7);

    SleepSample night(int daysAgo) => _asleep(
      morning(daysAgo).subtract(const Duration(hours: 8)),
      morning(daysAgo),
    );

    /// A platform night an old rule made: stored, but no longer produced.
    String leftBehind(
      AppStore store,
      int daysAgo, {
      ChangeSource source = ChangeSource.healthKit,
      String prefix = 'healthkit',
    }) {
      final end = morning(daysAgo);
      final id = '$prefix-sleep-orphan-$daysAgo-${source.name}';
      JournalRepository(store.backend.db).addSleep(
        SleepEntry(
          id: id,
          sleptAt: end,
          duration: const Duration(hours: 1),
          startedAt: end.subtract(const Duration(hours: 1)),
        ),
        source: source,
      );
      return id;
    }

    bool isLive(AppStore store, String id) =>
        store.backend.db.select(
          'SELECT deleted_at FROM sleep_entries WHERE id = ?',
          [id],
        ).single['deleted_at'] ==
        null;

    Future<AppStore> connected(_FakeHealth health) async {
      final store = storeWith(health);
      await store.connectHealth();
      return store;
    }

    test('are removed, with the reason on the audit trail', () async {
      final health = _FakeHealth([night(3), night(2), night(1)]);
      final store = await connected(health);
      final orphan = leftBehind(store, 5);

      await store.syncHealth();

      expect(isLive(store, orphan), isFalse);
      final event = store.backend.db.select(
        'SELECT source, payload FROM audit_events WHERE entity_id = ? '
        "AND action = 'delete'",
        [orphan],
      ).single;
      expect(event['source'], 'healthKit');
      expect(event['payload'], contains('orphan'));
      expect(
        store.backend.sleep.day(morning(1)).single.entry.duration,
        const Duration(hours: 8),
        reason: 'what the read produced stays',
      );
    });

    test(
      'the first read after an update clears what the old rule made',
      () async {
        final health = _FakeHealth([night(3), night(2)]);
        final store = storeWith(health);
        // Stored by an earlier version, before its full read was redone.
        final orphan = leftBehind(store, 4);
        store.backend.db.setSetting('health.full_read_version', '5');
        store.backend.db.setSetting('health.synced_at', '1');
        store.backend.db.setSetting('health.connected', 'true');

        await store.syncHealth();

        expect(isLive(store, orphan), isFalse);
        expect(health.readFrom.length, greaterThan(1), reason: 'a full read');
      },
    );

    test('never touch what the user touched, or typed in, or is not '
        'platform', () async {
      final health = _FakeHealth([night(3), night(2), night(1)]);
      final store = await connected(health);
      final journal = store.backend.journal;
      final repository = JournalRepository(store.backend.db);

      final overridden = leftBehind(store, 6);
      journal.setSleepKind(overridden, SleepKind.nap);
      final rated = leftBehind(store, 7);
      journal.updateSleep(
        SleepEntry(
          id: rated,
          sleptAt: morning(7),
          duration: const Duration(hours: 1),
          score: 5,
        ),
      );
      final typed = leftBehind(store, 8, source: ChangeSource.local);
      final demo = leftBehind(store, 9, source: ChangeSource.seed);
      final otherPlatform = leftBehind(
        store,
        10,
        source: ChangeSource.healthConnect,
        prefix: 'healthconnect',
      );
      expect(repository.sleepRow(overridden), isNotNull);

      await store.syncHealth();

      for (final id in [overridden, rated, typed, demo, otherPlatform]) {
        expect(isLive(store, id), isTrue, reason: id);
      }
    });

    test('only touch a sleep the read covered in full', () async {
      final health = _FakeHealth([night(3), night(2), night(1)]);
      final store = await connected(health);
      // Older than the 30 days the read reaches, and one that began
      // before the rolling window's first day was complete.
      final old = leftBehind(store, 60);
      final edge = leftBehind(store, 30);

      await store.syncHealth();

      expect(isLive(store, old), isTrue);
      expect(isLive(store, edge), isTrue);
    });

    test('an empty read removes nothing', () async {
      final health = _FakeHealth([night(3), night(2), night(1)]);
      final store = await connected(health);
      final orphan = leftBehind(store, 5);

      health.samples = [];
      await store.syncHealth();

      expect(isLive(store, orphan), isTrue, reason: 'a refused read is empty');
    });

    test(
      'a read that would remove most of what it covers removes none',
      () async {
        final health = _FakeHealth([night(3), night(2), night(1)]);
        final store = await connected(health);
        final orphans = [
          for (final days in [4, 5, 6, 7]) leftBehind(store, days),
        ];

        await store.syncHealth();

        for (final id in orphans) {
          expect(isLive(store, id), isTrue, reason: id);
        }
      },
    );

    test('one a platform removed comes back when it is produced again, one '
        'the user deleted does not', () async {
      final health = _FakeHealth([night(3), night(2), night(1)]);
      final store = await connected(health);
      final produced = store.backend.sleep.day(morning(2)).single.entry.id;
      final deletedByUser = store.backend.sleep.day(morning(3)).single.entry.id;
      store.backend.journal.delete(deletedByUser);

      // The platform stops producing the night of two days ago: removed.
      health.samples = [night(3), night(1)];
      await store.syncHealth();
      expect(isLive(store, produced), isFalse);
      expect(
        store.backend.db.select(
          'SELECT source FROM audit_events WHERE entity_id = ? '
          "AND action = 'delete'",
          [produced],
        ).single['source'],
        'healthKit',
      );

      health.samples = [night(3), night(2), night(1)];
      await store.syncHealth();
      expect(isLive(store, produced), isTrue, reason: 'revived');
      expect(
        store.backend.db.select(
          'SELECT source FROM audit_events WHERE entity_id = ? '
          "AND action = 'restore'",
          [produced],
        ).single['source'],
        'healthKit',
      );
      expect(isLive(store, deletedByUser), isFalse, reason: 'theirs to keep');
    });
  });

  group('sleep screens with naps', () {
    final clock = FakeClock();

    AppStore newStore() => AppStore(clock: clock.now, isOnboarded: true);

    testWidgets('Today adds the day\'s naps to the sleep tile', (tester) async {
      final store = newStore();
      final wake = DateTime(2026, 9, 19, 7);
      store.backend.journal.recordSleep(
        const Duration(hours: 8),
        at: wake,
        startedAt: wake.subtract(const Duration(hours: 8)),
      );
      await pumpScreen(tester, const TodayScreen(), store: store);
      expect(find.text('含小睡共 8 小時 40 分'), findsNothing);

      store.backend.journal.recordSleep(
        const Duration(minutes: 40),
        at: DateTime(2026, 9, 19, 14, 40),
        startedAt: DateTime(2026, 9, 19, 14),
        kind: SleepKind.nap,
      );
      await tester.pump();
      expect(find.text('含小睡共 8 小時 40 分'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('Today with only a nap leaves the main value empty', (
      tester,
    ) async {
      final store = newStore();
      store.backend.journal.recordSleep(
        const Duration(minutes: 40),
        at: DateTime(2026, 9, 19, 14, 40),
        startedAt: DateTime(2026, 9, 19, 14),
        kind: SleepKind.nap,
      );
      await pumpScreen(tester, const TodayScreen(), store: store);
      expect(find.text('含小睡共 40 分'), findsOneWidget);
      expect(
        find.text('40 分'),
        findsNothing,
        reason: 'a nap is not last night',
      );
      await disposeTree(tester);
    });

    testWidgets('a nap card opens the sleep page, whose switch makes it the '
        'night and undoes both', (tester) async {
      final store = newStore();
      final backend = store.backend;
      final wake = DateTime(2026, 9, 19, 7);
      final night = backend.journal.recordSleep(
        const Duration(hours: 8),
        at: wake,
        startedAt: wake.subtract(const Duration(hours: 8)),
      );
      final nap = backend.journal.recordSleep(
        const Duration(minutes: 40),
        at: DateTime(2026, 9, 19, 14, 40),
        startedAt: DateTime(2026, 9, 19, 14),
        kind: SleepKind.nap,
      );
      await pumpScreen(
        tester,
        SleepScreen(day: DateTime(2026, 9, 19)),
        store: store,
      );

      await tester.tap(find.text('14:00–14:40'));
      await tester.pumpAndSettle();
      expect(find.byType(JournalDetailScreen), findsOneWidget);
      final switchOn = find.byType(Switch);
      expect(tester.widget<Switch>(switchOn).value, isTrue);

      await tester.tap(switchOn);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        (backend.journal.entry(nap.id)! as SleepEntry).kind,
        SleepKind.night,
      );
      expect(
        (backend.journal.entry(night.id)! as SleepEntry).kind,
        SleepKind.nap,
      );

      await tester.tap(find.text('復原'));
      await tester.pump();
      expect(
        (backend.journal.entry(nap.id)! as SleepEntry).kind,
        SleepKind.nap,
      );
      expect(
        (backend.journal.entry(night.id)! as SleepEntry).kind,
        SleepKind.night,
      );
      await disposeTree(tester);
    });
  });
}
