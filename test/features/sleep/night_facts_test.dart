import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/sleep/night_band_chart.dart';
import 'package:mishirube/features/sleep/sleep_screen.dart';

import '../../support/harness.dart';

void main() {
  /// A night ending [back] mornings ago at 07:00, asleep from [bed]
  /// minutes after the midnight before, with one stretch awake of [awake]
  /// minutes in the middle of it, and its heart rate when [heartRate] is
  /// given.
  void addNight(
    AppStore store,
    int back, {
    int bed = 23 * 60,
    int wake = 7 * 60,
    int awake = 10,
    double? heartRate,
  }) {
    final now = store.now();
    final woke = DateTime(
      now.year,
      now.month,
      now.day - back,
    ).add(Duration(minutes: wake));
    final start = DateTime(
      now.year,
      now.month,
      now.day - back - 1,
    ).add(Duration(minutes: bed));
    final length = woke.difference(start).inMinutes;
    SleepSample stretch(SleepStage stage, int from, int to) => SleepSample(
      start: start.add(Duration(minutes: from)),
      end: start.add(Duration(minutes: to)),
      stage: stage,
      source: 'watch',
    );
    final id = 'night-$back';
    store.backend.storage.journal
      ..addSleep(
        SleepEntry(
          id: id,
          sleptAt: woke,
          duration: Duration(minutes: length - awake),
          startedAt: start,
        ),
        source: ChangeSource.healthKit,
      )
      ..replaceSleepSegments(id, [
        stretch(SleepStage.core, 0, 200),
        stretch(SleepStage.awake, 200, 200 + awake),
        stretch(SleepStage.deep, 200 + awake, length),
      ], source: ChangeSource.healthKit);
    if (heartRate != null) {
      store.backend.storage.journal.replaceSleepReadings(id, [
        OvernightReading(
          measure: OvernightMeasure.heartRate,
          minimum: heartRate - 8,
          maximum: heartRate + 20,
          average: heartRate,
          count: 200,
        ),
      ], source: ChangeSource.healthKit);
    }
  }

  AppStore emptyStore({FakeClock? clock}) {
    final store = AppStore(
      clock: (clock ?? FakeClock()).now,
      isOnboarded: true,
    );
    store.backend.provenance.setShowsDemo(false);
    return store;
  }

  /// Fourteen ordinary nights, then the one shown: asleep at [bed] with
  /// [awake] minutes awake in it.
  AppStore withUsualNights({
    int before = 14,
    required int bed,
    int wake = 7 * 60,
    required int awake,
    double? heartRate,
    FakeClock? clock,
  }) {
    final store = emptyStore(clock: clock);
    for (var back = before; back >= 1; back--) {
      addNight(
        store,
        back,
        // Always 23:00, and 5 to 20 minutes awake.
        awake: 5 + (back % 4) * 5,
        heartRate: heartRate == null ? null : 58.0 + back % 3,
      );
    }
    addNight(
      store,
      0,
      bed: bed,
      wake: wake,
      awake: awake,
      heartRate: heartRate,
    );
    return store;
  }

  // The page builds its sections as they scroll into view.
  Future<void> scrollTo(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );

  testWidgets('a night is read against the nights before it, as facts', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await pumpScreen(
      tester,
      const SleepScreen(),
      store: withUsualNights(bed: 21 * 60 + 57, awake: 45),
    );

    await scrollTo(tester, find.text('與平常相比'));
    expect(find.text('與平常相比'), findsOneWidget);
    expect(find.text('入睡時間'), findsOneWidget);
    expect(find.text('21:57'), findsOneWidget);
    expect(
      find.text('比平均早 1 小時 3 分'),
      findsOneWidget,
      reason: '23:00 on every night before it',
    );
    expect(
      find.text('依近 28 天 14 晚'),
      findsNWidgets(3),
      reason: 'each says how many nights it rests on',
    );
    expect(find.text('起床時間'), findsOneWidget);
    expect(find.text('與平均相同'), findsOneWidget, reason: '07:00 as always');

    // Where the night was awake is read against its usual, and said once.
    expect(find.text('夜間清醒', skipOffstage: false), findsOneWidget);
    expect(find.text('45 分', skipOffstage: false), findsWidgets);
    expect(
      find.text('醒來 1 次 · 平常 5 分–20 分', skipOffstage: false),
      findsOneWidget,
    );

    // Facts about how it differs, never a verdict or a total.
    expect(find.textContaining('分數'), findsNothing);
    expect(find.textContaining('項在範圍內'), findsNothing);
    expect(find.textContaining('異常'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('a night that began later is said to be later', (tester) async {
    usePhoneViewport(tester);
    await pumpScreen(
      tester,
      const SleepScreen(),
      store: withUsualNights(bed: 24 * 60 + 30, awake: 10),
    );

    await scrollTo(tester, find.text('比平均晚 1 小時 30 分'));
    expect(find.text('比平均晚 1 小時 30 分'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('waking is read against the nights before too', (tester) async {
    usePhoneViewport(tester);
    await pumpScreen(
      tester,
      const SleepScreen(),
      store: withUsualNights(bed: 23 * 60, wake: 9 * 60 + 30, awake: 10),
    );

    await scrollTo(tester, find.text('09:30'));
    expect(find.text('09:30'), findsOneWidget);
    expect(find.text('比平均晚 2 小時 30 分'), findsOneWidget);
    expect(find.text('與平均相同'), findsOneWidget, reason: 'bedtime as usual');
    await disposeTree(tester);
  });

  testWidgets('a few nights are not what is usual: no comparison is made', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await pumpScreen(
      tester,
      const SleepScreen(),
      store: withUsualNights(before: 5, bed: 21 * 60 + 57, awake: 45),
    );

    // Past where the card would be, so its absence is not just not built yet.
    await scrollTo(tester, find.text('夜間清醒'));
    expect(find.text('與平常相比'), findsNothing);
    expect(find.textContaining('比平均'), findsNothing);
    // The time awake is still there, in the section it always was.
    expect(find.text('夜間清醒', skipOffstage: false), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('each reading is a dot on its usual range, one ringed outside', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await pumpScreen(
      tester,
      const SleepScreen(),
      store: withUsualNights(bed: 23 * 60, awake: 10, heartRate: 80),
    );

    final chart = find.byType(NightBandChart);
    await tester.scrollUntilVisible(
      chart,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(chart, findsOneWidget);
    final columns = tester.widget<NightBandChart>(chart).columns;
    expect(columns, hasLength(1), reason: 'only heart rate has a range');
    expect(columns.single.measure, OvernightMeasure.heartRate);
    expect(columns.single.isOutside, isTrue, reason: '80 against 58–60');
    expect(columns.single.label, contains('平常'));
    expect(columns.single.label, endsWith('範圍外'));
    expect(find.text('範圍外'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('no usual range, no chart; readings stay in their list', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = emptyStore();
    addNight(store, 0, heartRate: 60);
    await pumpScreen(tester, const SleepScreen(), store: store);

    await tester.scrollUntilVisible(
      find.text('心率'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(NightBandChart), findsNothing);
    expect(find.text('心率'), findsOneWidget);
    await disposeTree(tester);
  });

  group('what was logged that evening', () {
    /// Logs a drink at [at] and, when [workoutAt] is given, a workout.
    AppStore withLog({DateTime? drinkAt, DateTime? workoutAt}) {
      final clock = FakeClock();
      final store = withUsualNights(
        bed: 23 * 60,
        awake: 10,
        heartRate: 58,
        clock: clock,
      );
      if (drinkAt != null) {
        store.backend.nutrition.logMeal(
          const MealEvent(
            id: 'wine',
            name: '紅酒',
            timeLabel: '20:00',
            qualityTag: '手動',
            dishes: [],
            nutrients: {Nutrient.alcohol: 14},
          ),
          eatenAt: drinkAt,
        );
      }
      if (workoutAt != null) {
        final now = clock.current;
        clock.current = workoutAt;
        store
          ..startWorkout()
          ..completeNextSet()
          ..finishWorkout();
        clock.current = now;
      }
      return store;
    }

    Future<void> openReadings(WidgetTester tester, AppStore store) async {
      usePhoneViewport(tester);
      await pumpScreen(tester, const SleepScreen(), store: store);
      await tester.scrollUntilVisible(
        find.text('夜間資料'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }

    testWidgets('is said beside the readings, never as a cause', (
      tester,
    ) async {
      // The night began 23:00 on the 18th: the 18th's evening before it.
      await openReadings(
        tester,
        withLog(
          drinkAt: DateTime(2026, 9, 18, 20),
          workoutAt: DateTime(2026, 9, 18, 18),
        ),
      );

      expect(find.text('同一天記下飲酒'), findsOneWidget);
      expect(find.text('同一天記下訓練'), findsOneWidget);
      expect(find.textContaining('原因'), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('leaves out what was logged after the night began or days '
        'before', (tester) async {
      await openReadings(
        tester,
        withLog(
          // After 23:00 that night began, and two evenings before it.
          drinkAt: DateTime(2026, 9, 19, 6),
          workoutAt: DateTime(2026, 9, 17, 18),
        ),
      );

      expect(find.text('夜間資料'), findsOneWidget);
      expect(find.textContaining('同一天記下'), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('says nothing on a night with nothing logged', (tester) async {
      await openReadings(tester, withLog());

      expect(find.textContaining('同一天記下'), findsNothing);
      await disposeTree(tester);
    });
  });

  group('the dots', () {
    Future<void> pumpChart(
      WidgetTester tester,
      List<NightBandColumn> columns,
    ) async {
      usePhoneViewport(tester);
      await pumpScreen(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: NightBandChart(columns: columns),
          ),
        ),
        store: emptyStore(),
      );
    }

    /// The dots, in the order of their columns: a ring is outside.
    List<BoxDecoration> dots(WidgetTester tester) => [
      for (final positioned in tester.widgetList<Positioned>(
        find.descendant(
          of: find.byType(NightBandChart),
          matching: find.byType(Positioned),
        ),
      ))
        if (positioned.child case final Container container)
          container.decoration! as BoxDecoration,
    ];

    testWidgets('a missing reading leaves its column empty', (tester) async {
      await pumpChart(tester, const [
        NightBandColumn(
          measure: OvernightMeasure.heartRate,
          share: 0.5,
          label: 'a',
        ),
        NightBandColumn(
          measure: OvernightMeasure.respiratoryRate,
          share: null,
          label: '',
        ),
        NightBandColumn(
          measure: OvernightMeasure.oxygenSaturation,
          share: 1.4,
          label: 'c',
        ),
      ]);

      final decorations = dots(tester);
      expect(decorations, hasLength(2), reason: 'two readings, three columns');
      expect(decorations.first.border, isNull, reason: 'inside: filled');
      expect(decorations.last.border, isNotNull, reason: 'outside: a ring');
      expect(find.byIcon(Icons.air), findsOneWidget, reason: 'still a column');
      await disposeTree(tester);
    });

    testWidgets('a position is higher the higher the reading', (tester) async {
      await pumpChart(tester, const [
        NightBandColumn(
          measure: OvernightMeasure.heartRate,
          share: -0.6,
          label: 'low',
        ),
        NightBandColumn(
          measure: OvernightMeasure.respiratoryRate,
          share: 0.5,
          label: 'in',
        ),
        NightBandColumn(
          measure: OvernightMeasure.oxygenSaturation,
          share: 1.6,
          label: 'high',
        ),
      ]);

      final tops = [
        for (final positioned in tester.widgetList<Positioned>(
          find.descendant(
            of: find.byType(NightBandChart),
            matching: find.byType(Positioned),
          ),
        ))
          if (positioned.child is Container) positioned.top!,
      ];
      expect(tops[0], greaterThan(tops[1]));
      expect(tops[1], greaterThan(tops[2]));
      await disposeTree(tester);
    });

    testWidgets('a reading far outside stays whole inside the plot', (
      tester,
    ) async {
      await pumpChart(tester, const [
        NightBandColumn(
          measure: OvernightMeasure.heartRate,
          share: 9,
          label: 'far above',
        ),
        NightBandColumn(
          measure: OvernightMeasure.respiratoryRate,
          share: -9,
          label: 'far below',
        ),
      ]);

      final plot = tester.getRect(
        find
            .descendant(
              of: find.byType(NightBandChart),
              matching: find.byType(LayoutBuilder),
            )
            .first,
      );
      for (final positioned in tester.widgetList<Positioned>(
        find.descendant(
          of: find.byType(NightBandChart),
          matching: find.byType(Positioned),
        ),
      )) {
        if (positioned.child is! Container) continue;
        expect(positioned.top!, greaterThanOrEqualTo(0));
        expect(positioned.top! + 12, lessThanOrEqualTo(plot.height));
      }
      await disposeTree(tester);
    });

    testWidgets('a legend names the range, and a ring only when one is', (
      tester,
    ) async {
      await pumpChart(tester, const [
        NightBandColumn(
          measure: OvernightMeasure.heartRate,
          share: 0.5,
          label: 'a',
        ),
      ]);
      expect(find.text('平常範圍'), findsOneWidget);
      expect(find.text('範圍外'), findsNothing);
      await disposeTree(tester);
    });
  });
}
