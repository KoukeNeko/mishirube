import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/app/caffeine_activity.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/shared/format.dart';

import 'support/harness.dart';

void main() {
  const channel = MethodChannel('mishirube/caffeine_activity');

  /// The calls made to the native side, which shows whatever it is asked.
  List<MethodCall> recordCalls(WidgetTester tester) {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return call.method == 'show' ? true : null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    return calls;
  }

  AppStore emptyDay() {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.provenance.setShowsDemo(false);
    return store;
  }

  void logCoffee(AppStore store, String id, {required Duration ago}) {
    final at = store.now().subtract(ago);
    store.backend.nutrition.logMeal(
      MealEvent(
        id: id,
        name: '美式咖啡',
        timeLabel: formatTimeOfDay(at),
        qualityTag: '手動',
        dishes: const [],
        kind: ConsumptionKind.beverage,
        nutrients: const {Nutrient.caffeine: 120},
      ),
      eatenAt: at,
    );
  }

  testWidgets('caffeine over the bedtime reference is handed to the lock '
      'screen with the time it falls under it, and taken back', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final calls = recordCalls(tester);
    final store = emptyDay();
    await pumpScreen(
      tester,
      const CaffeineActivity(child: SizedBox.shrink()),
      store: store,
    );
    expect(calls.single.method, 'end', reason: 'nothing over the reference');

    // 120 mg an hour before 19:43: 104 mg now, under 35 mg at 03:37.
    logCoffee(store, 'americano', ago: const Duration(hours: 1));
    await tester.pump();

    final shown = calls.last;
    final arguments = shown.arguments as Map<Object?, Object?>;
    final below = DateTime(2026, 9, 20, 3, 40);
    expect(shown.method, 'show');
    expect(
      arguments['belowAt'],
      below.millisecondsSinceEpoch.toDouble(),
      reason: 'rounded up to the next ten minutes',
    );
    expect(arguments['belowTime'], formatTimeOfDay(below));
    expect(arguments['cup'], '美式咖啡 · 120 mg');
    expect(arguments['belowLabel'], '低於就寢參考');
    expect(arguments['bedtimeAt'], isNull, reason: 'no sleep goal');

    final sent = calls.length;
    store.backend.nutrition.logWater(250);
    await tester.pump();
    expect(calls, hasLength(sent), reason: 'nothing it shows changed');

    store.backend.nutrition.setCaffeineActivity(false);
    await tester.pump();
    expect(calls.last.method, 'end');

    await disposeTree(tester);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('ended from Today it stays away for that cup, and the next '
      'cup brings it back', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final calls = recordCalls(tester);
    final store = emptyDay();
    CaffeineActivityScope? scope;
    await pumpScreen(
      tester,
      CaffeineActivity(
        child: Builder(
          builder: (context) {
            scope = CaffeineActivityScope.maybeOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
      store: store,
    );
    expect(scope!.isShowing, isFalse);

    logCoffee(store, 'first', ago: const Duration(hours: 1));
    await tester.pumpAndSettle();
    expect(scope!.isShowing, isTrue);

    scope!.end();
    await tester.pumpAndSettle();
    expect(calls.last.method, 'end');
    expect(scope!.isShowing, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(calls.last.method, 'end', reason: 'not back for the same cup');

    logCoffee(store, 'second', ago: const Duration(minutes: 20));
    await tester.pumpAndSettle();
    expect(calls.last.method, 'show');
    expect(scope!.isShowing, isTrue);

    await disposeTree(tester);
    debugDefaultTargetPlatformOverride = null;
  });
}
