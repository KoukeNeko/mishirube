import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/nutrition/daily_nutrition_screen.dart';

import '../../support/harness.dart';

void main() {
  /// Each meal share bar's fills, as far across as they are drawn.
  List<double> fills(WidgetTester tester) => [
    for (final box in tester.widgetList<FractionallySizedBox>(
      find.byWidgetPredicate(
        (widget) =>
            widget is FractionallySizedBox && widget.child is ColoredBox,
      ),
    ))
      box.widthFactor!,
  ];

  testWidgets('meal shares rise into place as they are shown', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.provenance.setShowsDemo(false);
    final now = store.now();
    for (final (id, kcal, hour) in [
      ('breakfast', 400.0, 8),
      ('lunch', 600.0, 12),
    ]) {
      store.backend.nutrition.logMeal(
        MealEvent(
          id: id,
          name: id,
          timeLabel: '$hour:00',
          qualityTag: '手動',
          dishes: const [],
          kcal: kcal,
          proteinGrams: kcal / 20,
        ),
        eatenAt: DateTime(now.year, now.month, now.day, hour),
      );
    }
    await pumpScreen(tester, const DailyNutritionScreen(), store: store);
    final link = find.text('佔比');
    await tester.scrollUntilVisible(
      link,
      200,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await Scrollable.ensureVisible(tester.element(link), alignment: 0.2);
    await tester.pumpAndSettle();
    expect(fills(tester), isEmpty, reason: 'hidden until asked for');

    await tester.tap(link);
    await tester.pump();
    expect(fills(tester), isNotEmpty);
    expect(fills(tester), everyElement(0), reason: 'drawn in from nothing');

    await tester.pumpAndSettle();
    expect(
      fills(tester).where((fill) => fill > 0),
      isNotEmpty,
      reason: 'filled to each meal\'s share',
    );
    await disposeTree(tester);
  });
}
