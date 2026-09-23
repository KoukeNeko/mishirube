import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/engines/food_portion.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/nutrition/daily_nutrition_screen.dart';
import 'package:mishirube/features/today/today_screen.dart';

import 'support/harness.dart';

/// The half of `research/31-usability-protocol.md` a machine can answer.
///
/// The protocol's five-second questions ("how many meals did you eat
/// today?") need people. What does not need people is the condition
/// underneath them: the answer has to be on the screen and it has to be
/// right. A fact that is missing or wrong fails the human test too — it
/// just wastes a participant to find out.
///
/// These tests do not replace the sessions, and passing them is not
/// passing the protocol. They stop a session being spent on something a
/// test could have caught.
void main() {
  /// Scrolls [finder] into view the way a lazy list needs.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isNotEmpty) return;
    await tester.dragUntilVisible(
      finder,
      find.byType(CustomScrollView).first,
      const Offset(0, -120),
    );
  }

  /// A drink with caffeine in it, the way task A3 asks for.
  FoodPortion coffee() => FoodPortion(
    FoodItem(
      id: 'usability-coffee',
      name: '美式咖啡',
      kind: ConsumptionKind.beverage,
      servingUnit: ServingUnit.millilitre,
      servingAmount: 355,
      nutrients: const {Nutrient.caffeine: 150},
    ),
    1,
  );

  testWidgets('a drink is a record, not a sitting', (tester) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    // The evening card is the one that reports a count; the morning one
    // offers to record breakfast instead.
    while (store.phase != DayPhase.evening) {
      store.cyclePhase();
    }
    await pumpScreen(tester, const TodayScreen(), store: store);

    final meals = store.todaySummary.mealCount;
    store.logWater();
    store.logPortion(coffee());
    await tester.pumpAndSettle();

    expect(
      store.todaySummary.mealCount,
      meals,
      reason: 'the engine already knows two drinks are not two meals',
    );
    await reveal(tester, find.textContaining('$meals 餐'));
    expect(
      find.textContaining('$meals 餐'),
      findsOneWidget,
      reason:
          'and the card has to say the number the engine says. '
          'Protocol question B1 asks a participant to read this off the '
          'screen, so a second count here would have cost a session to '
          'find.',
    );
    await disposeTree(tester);
  });

  testWidgets('the day counts the same meals Today does', (tester) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final meals = store.todaySummary.mealCount;
    store.logWater();
    await pumpScreen(
      tester,
      DailyNutritionScreen(day: store.now()),
      store: store,
    );
    await tester.pumpAndSettle();

    await reveal(tester, find.textContaining('餐 ·'));
    expect(
      find.textContaining('$meals 餐'),
      findsOneWidget,
      reason:
          'two screens answering the same question differently is '
          'the failure the density test is looking for',
    );
    await disposeTree(tester);
  });

  testWidgets('a macro some meals lacked says what it left out', (
    tester,
  ) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    // The card with the macro tiles is the midday one.
    while (store.phase != DayPhase.noon) {
      store.cyclePhase();
    }
    store.logPortion(
      FoodPortion(FoodItem(id: 'bar', name: '能量棒', kcal: 200), 1),
    );
    await pumpScreen(tester, const TodayScreen(), store: store);
    await tester.pumpAndSettle();

    await reveal(tester, find.text('蛋白質'));
    expect(
      find.textContaining('蛋白質、碳水化合物、脂肪、膳食纖維有紀錄沒有數字，未計入'),
      findsOneWidget,
      reason:
          'a bar with only its energy printed adds nothing to the '
          'protein total, so the card says the total leaves it out — '
          'in words, not a symbol people have to decode',
    );
    await disposeTree(tester);
  });

  testWidgets('an estimate says it is one and what it was worked from', (
    tester,
  ) async {
    final clock = FakeClock();
    final store = AppStore(clock: clock.now, isOnboarded: true);
    store.logPortion(coffee());
    // The estimate reads what was drunk before now, so a cup logged in
    // this very millisecond is not yet in the body.
    clock.advance(const Duration(minutes: 30));
    await pumpScreen(
      tester,
      DailyNutritionScreen(day: store.now()),
      store: store,
    );
    await tester.pumpAndSettle();

    await reveal(tester, find.textContaining('估計殘留咖啡因'));
    expect(
      find.textContaining('半衰期'),
      findsOneWidget,
      reason:
          'the number is labelled an estimate in words, and the screen '
          'says what it was worked out from',
    );
    await disposeTree(tester);
  });
}
