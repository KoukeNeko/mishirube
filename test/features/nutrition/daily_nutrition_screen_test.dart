import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/nutrition/daily_nutrition_screen.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

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

  testWidgets('the day is figures in groups, as 今天 draws its meals', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.provenance.setShowsDemo(false);
    final now = store.now();
    store.backend.nutrition.logMeal(
      MealEvent(
        id: 'lunch',
        name: '雞腿便當',
        timeLabel: '12:00',
        qualityTag: '手動',
        dishes: const [],
        kcal: 780,
        proteinGrams: 35,
        carbGrams: 95,
        fatGrams: 28,
        fibreGrams: 5,
      ),
      eatenAt: DateTime(now.year, now.month, now.day, 12),
    );
    await pumpScreen(tester, const DailyNutritionScreen(), store: store);

    final hero = tester.widget<SegmentHero>(find.byType(SegmentHero));
    expect(hero.value, contains('780'), reason: 'eaten, with no target set');
    for (final name in [testL10n.macroProtein, testL10n.macroCarb]) {
      expect(
        find.byWidgetPredicate(
          (widget) => widget is SegmentStat && widget.label == name,
        ),
        findsOneWidget,
        reason: name,
      );
    }
    expect([
      for (final heading in tester.widgetList<CategoryHeading>(
        find.byType(CategoryHeading),
      ))
        heading.label,
    ], containsAll([testL10n.macroEnergy, '每日指標', '餐點']));
    await disposeTree(tester);
  });
}
