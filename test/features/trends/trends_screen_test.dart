import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:flutter/material.dart';
import 'package:mishirube/features/trends/muscle_load_card.dart';
import 'package:mishirube/features/trends/muscle_map.dart';
import 'package:mishirube/features/trends/trends_screen.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('an insight without the records says what it needs', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const TrendsScreen(), store: store);

    expect(find.text('體重與飲食'), findsOneWidget);
    expect(find.text('能量平衡'), findsOneWidget);
    expect(find.textContaining('需要近 21 天有 14 天完整飲食'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('every area logged has a long-run row, even without records', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const TrendsScreen(), store: store);

    for (final area in ['身體', '訓練', '睡眠', '飲食', '活動']) {
      final row = find.widgetWithText(NavRow, area);
      await tester.dragUntilVisible(
        row,
        find.byType(CustomScrollView).hitTestable().first,
        const Offset(0, -200),
      );
      expect(row, findsOneWidget, reason: area);
    }
    await disposeTree(tester);
  });

  testWidgets("the week's training shows where the sets went", (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const TrendsScreen(), store: store);

    final map = find.byType(MuscleMap);
    await tester.dragUntilVisible(
      map,
      find.byType(CustomScrollView).hitTestable().first,
      const Offset(0, -200),
    );
    expect(map, findsOneWidget);
    final card = tester.getSize(
      find.ancestor(of: map, matching: find.byType(AppCard)),
    );
    expect(
      tester.getSize(map).height,
      lessThanOrEqualTo(card.width / 2),
      reason: 'a glance, not the whole card',
    );
    final bars = find.byType(MuscleSetBars);
    expect(bars, findsOneWidget, reason: 'how much, beside where');
    expect(
      tester
          .widgetList(
            find.descendant(of: bars, matching: find.byType(ClipRRect)),
          )
          .length,
      inInclusiveRange(1, 3),
      reason: 'only the most trained',
    );
    await disposeTree(tester);
  });

  testWidgets('before four workouts the map shows, with what the rest needs', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final clock = FakeClock();
    final store = AppStore(clock: clock.now, isOnboarded: true);
    // Past the demo's workouts, then one of the user's own.
    clock.advance(const Duration(days: 90));
    // The first set is a warm-up, which counts for no muscle.
    store
      ..startWorkout()
      ..completeNextSet()
      ..completeNextSet()
      ..completeNextSet()
      ..finishWorkout();
    await pumpScreen(tester, const TrendsScreen(), store: store);

    final map = find.byType(MuscleMap);
    await tester.dragUntilVisible(
      map,
      find.byType(CustomScrollView).hitTestable().first,
      const Offset(0, -200),
    );
    expect(map, findsOneWidget);
    expect(find.text('需要近 4 週至少 4 次訓練（目前 1 次）'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('a single week is still drawn', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Sparkline(values: [null, null, 3742]),
      ),
    );
    expect(
      tester.renderObject(
        find.descendant(
          of: find.byType(Sparkline),
          matching: find.byType(CustomPaint),
        ),
      ),
      paints..circle(),
    );
  });
}
