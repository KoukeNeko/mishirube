import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/app/widget_snapshot.dart';
import 'package:mishirube/backend/engines/caffeine.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/water/water_screen.dart';

import 'support/harness.dart';

void main() {
  /// A store with the demo records hidden: the day as a new user has it.
  AppStore emptyDay() {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.provenance.setShowsDemo(false);
    return store;
  }

  Map<String, Object?> snapshotOf(AppStore store) =>
      widgetSnapshot(store, testL10n);

  test(
    'an empty day says so, with nothing the widgets would draw as a zero',
    () {
      final snapshot = snapshotOf(emptyDay());

      expect(snapshot['version'], widgetSnapshotVersion);
      expect(snapshot['day'], '2026-09-19');
      expect(snapshot['caffeine'], isNull, reason: 'not 0 mg');
      expect(snapshot['training'], isNull);
      expect((snapshot['weight'] as Map)['kg'], isNull);
      expect((snapshot['sleep'] as Map)['asleepMinutes'], isNull);
      expect((snapshot['goal'] as Map)['enabled'], isFalse);
      expect(() => jsonEncode(snapshot), returnsNormally);
    },
  );

  test('what was recorded today is in it, in the app\'s own words', () {
    final store = emptyDay();
    final at = store.now().subtract(const Duration(hours: 5));
    store.backend.nutrition.logMeal(
      MealEvent(
        id: 'coffee',
        name: '美式',
        timeLabel: '14:43',
        qualityTag: '手動',
        dishes: const [],
        kind: ConsumptionKind.beverage,
        nutrients: const {Nutrient.caffeine: 200},
      ),
      eatenAt: at,
    );
    store.backend.nutrition.logWater(250);
    store.backend.journal.recordWeight(72.4);

    final snapshot = snapshotOf(store);

    final caffeine = snapshot['caffeine'] as Map<String, Object?>;
    final values = (caffeine['values'] as List).cast<double>();
    expect(values.length, 145, reason: 'eight hours back, sixteen ahead');
    expect(caffeine['stepMinutes'], 10);
    expect(values[48], closeTo(100, 0.1), reason: 'half after one half-life');
    expect(caffeine['reference'], caffeineBedtimeReferenceMg);
    expect(caffeine['referenceText'], '就寢參考 35 mg');
    expect((snapshot['water'] as Map)['ml'], 250);
    expect((snapshot['water'] as Map)['timesText'], '1 次');
    expect((snapshot['weight'] as Map)['kg'], 72.4);
    expect((snapshot['text'] as Map)['nutrition'], '飲食');
  });

  test(
    'the week the goal counts is given as days, for the widget to count',
    () {
      final store = emptyDay();
      store.backend.goal.setGoal(4, applyThisWeek: true);
      store.backend.goal.setEnabled(true);
      store.backend.journal.recordNote('x');
      final snapshot = snapshotOf(store);

      final goal = snapshot['goal'] as Map<String, Object?>;
      expect(goal['enabled'], isTrue);
      expect(goal['target'], 4);
      expect(goal['activeDays'], isA<List<Object?>>());
    },
  );

  testWidgets(
    'a write is handed over once it has settled, and a tap opens its page',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      usePhoneViewport(tester);
      final sent = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('mishirube/widgets'),
        (call) async {
          if (call.method == 'update') sent.add(call.arguments as String);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('mishirube/widgets'),
          null,
        ),
      );
      final store = emptyDay()..selectTab(HomeTab.today);
      await tester.pumpWidget(MishirubeApp(store: store));
      await tester.pump(const Duration(seconds: 2));
      expect(sent, hasLength(1), reason: 'what the widgets start from');

      store.backend.nutrition.logWater(250);
      await tester.pump();
      expect(sent, hasLength(1), reason: 'not at each write');
      await tester.pump(const Duration(seconds: 2));
      expect(sent, hasLength(2));
      expect((jsonDecode(sent.last) as Map)['water'], containsPair('ml', 250));

      await tester.pump(const Duration(seconds: 5));
      expect(sent, hasLength(2), reason: 'nothing changed, nothing reloaded');

      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'mishirube/widgets',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('open', 'mishirube://water'),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(find.byType(WaterScreen), findsOneWidget);
      await disposeTree(tester);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
