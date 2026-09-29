import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/caffeine/caffeine_card.dart';
import 'package:mishirube/features/caffeine/caffeine_screen.dart';
import 'package:mishirube/features/today/today_screen.dart';
import 'package:mishirube/features/today/today_view_model.dart';
import 'package:mishirube/features/today/today_widgets.dart';
import 'package:mishirube/shared/format.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import '../../support/harness.dart';

void main() {
  /// A store with the demo records hidden: the day as a new user has it.
  AppStore emptyDay() {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.provenance.setShowsDemo(false);
    return store;
  }

  testWidgets('a day with nothing recorded shows no zeros and no timeline', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await pumpScreen(tester, const TodayScreen(), store: emptyDay());

    expect(find.text('9 月 19 日（週六）'), findsOneWidget, reason: 'the date');
    expect(
      find.text('開始訓練'),
      findsNothing,
      reason: 'what to train next is not guessed',
    );
    expect(find.text('今天的紀錄'), findsNothing);
    expect(find.byType(IntakeCard), findsNothing, reason: 'not 0 kcal');
    expect(find.byType(CaffeineCard), findsNothing, reason: 'not 0 mg');
    expect(find.text('沒有紀錄'), findsWidgets);
    expect(find.textContaining('0 kcal'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('what was recorded today is listed in the order it happened', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = emptyDay();
    store.backend.journal
      ..recordWeight(72.4, at: store.now().subtract(const Duration(hours: 9)))
      ..recordNote('膝蓋有點緊');
    await pumpScreen(tester, const TodayScreen(), store: store);

    await tester.scrollUntilVisible(find.text('今天的紀錄'), 200);
    final weight = tester.getTopLeft(find.text('體重 72.4 kg')).dy;
    final note = tester.getTopLeft(find.textContaining('膝蓋有點緊')).dy;
    expect(weight, lessThan(note), reason: 'the morning weighing comes first');
    await disposeTree(tester);
  });

  testWidgets('a hidden section and a module turned off leave Today', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = emptyDay()..toggleModule(AppModule.sleep);
    store.backend.journal.recordWeight(72.4);
    TodayViewModel(store.backend)
      ..setShown(TodaySection.records, false)
      ..dispose();
    await pumpScreen(tester, const TodayScreen(), store: store);

    expect(find.text('睡眠'), findsNothing, reason: 'the module is off');
    expect(find.text('體重'), findsOneWidget);
    expect(find.text('今天的紀錄'), findsNothing, reason: 'hidden');
    await disposeTree(tester);
  });

  testWidgets('caffeine drunk today shows as a falling curve', (tester) async {
    usePhoneViewport(tester);
    final store = emptyDay();
    final at = store.now().subtract(const Duration(hours: 5));
    store.backend.nutrition.logMeal(
      MealEvent(
        id: 'coffee',
        name: '美式',
        timeLabel: formatTimeOfDay(at),
        qualityTag: '手動',
        dishes: const [],
        kind: ConsumptionKind.beverage,
        nutrients: const {Nutrient.caffeine: 200},
      ),
      eatenAt: at,
    );
    await pumpScreen(tester, const TodayScreen(), store: store);

    await tester.scrollUntilVisible(find.byType(CaffeineCard), 200);
    expect(
      find.text('100 mg', findRichText: true),
      findsOneWidget,
      reason: 'half of it after one half-life',
    );
    final chart = tester.widget<CurveChart>(find.byType(CurveChart));
    final area = tester.getRect(
      find.descendant(
        of: find.byType(CurveChart),
        matching: find.byType(CustomPaint),
      ),
    );
    final nowX =
        area.left + area.width * chart.nowIndex / (chart.values.length - 1);
    expect(
      tester.getCenter(find.text(formatTimeOfDay(store.now()))).dx,
      closeTo(nowX, 1),
      reason: 'the time of now sits under the line drawn at now',
    );

    await tester.tap(find.byType(CaffeineCard));
    await tester.pumpAndSettle();
    expect(find.byType(CaffeineScreen), findsOneWidget, reason: 'its own page');
    expect(find.text('美式'), findsOneWidget, reason: 'the cup it came from');
    await disposeTree(tester);
  });

  testWidgets('water fills the tile up to its reference and no further', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = emptyDay();
    store.backend.nutrition
      ..logWater(500)
      ..logWater(500);
    await pumpScreen(tester, const TodayScreen(), store: store);

    expect(find.text('1,000 / 1,500 mL', findRichText: true), findsOneWidget);
    expect(tester.widget<LevelFill>(find.byType(LevelFill)).level, 1000 / 1500);
    await disposeTree(tester);

    store.backend.nutrition.setWaterReferenceMl(null);
    await pumpScreen(tester, const TodayScreen(), store: store);
    expect(find.text('1,000 mL', findRichText: true), findsOneWidget);
    expect(find.byType(LevelFill), findsNothing, reason: 'no reference');
    await disposeTree(tester);
  });

  testWidgets('after training the workout done shows', (tester) async {
    usePhoneViewport(tester);
    final store = emptyDay()
      ..startWorkout()
      ..completeNextSet()
      ..finishWorkout();
    await pumpScreen(tester, const TodayScreen(), store: store);

    expect(find.byType(CompletedWorkoutCard), findsOneWidget);
    await disposeTree(tester);
  });
}
