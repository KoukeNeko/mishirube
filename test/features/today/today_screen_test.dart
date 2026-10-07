import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/backend/storage/journal_repository.dart';
import 'package:mishirube/features/bath/bath_screen.dart';
import 'package:mishirube/features/caffeine/caffeine_card.dart';
import 'package:mishirube/features/caffeine/caffeine_screen.dart';
import 'package:mishirube/features/body/body_screen.dart';
import 'package:mishirube/features/nutrition/daily_nutrition_screen.dart';
import 'package:mishirube/features/nutrition/meal_detail_screen.dart';
import 'package:mishirube/features/nutrition/meal_group_screen.dart';
import 'package:mishirube/features/today/today_screen.dart';
import 'package:mishirube/features/today/today_view_model.dart';
import 'package:mishirube/features/today/today_widgets.dart';
import 'package:mishirube/features/trends/insight_detail_screen.dart';
import 'package:mishirube/features/trends/training_trends_screen.dart';
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

  testWidgets('each insight opens the page it is about', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final insights = store.todayInsights;
    expect(insights.map((insight) => insight.kind), [
      InsightKind.bodyWeight,
      InsightKind.weeklyTraining,
    ], reason: 'the demo has something to say about weight and the week');
    await pumpScreen(tester, const TodayScreen(), store: store);

    for (final (insight, page) in <(Insight, Type)>[
      (insights[0], BodyScreen),
      (insights[1], TrainingTrendsScreen),
    ]) {
      final card = find.text(insight.statement);
      await tester.scrollUntilVisible(card, 200);
      await tester.ensureVisible(card);
      await tester.pump();
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(find.byType(page), findsOneWidget);
      expect(find.byType(InsightDetailScreen), findsNothing);
      await tester.tap(find.byType(AppBarBackButton));
      await tester.pumpAndSettle();
    }
    await disposeTree(tester);
  });

  testWidgets(
    'a meal put together opens as the whole meal, not its first item',
    (tester) async {
      usePhoneViewport(tester);
      final store = emptyDay();
      final nutrition = store.backend.nutrition;
      final items = [
        for (final (name, kcal) in [('蛋餅', 250.0), ('冰奶茶', 300.0)])
          nutrition.logMeal(
            MealEvent(
              id: name,
              name: name,
              timeLabel: '08:00',
              qualityTag: '手動',
              dishes: const [],
              kcal: kcal,
            ),
            eatenAt: store.now(),
          ),
      ];
      nutrition.groupMeals(items);
      await pumpScreen(tester, const TodayScreen(), store: store);

      Future<void> openRow(String title) async {
        await tester.scrollUntilVisible(find.text(title), 200);
        await tester.ensureVisible(find.text(title));
        await tester.pump();
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
      }

      await openRow('蛋餅、冰奶茶');
      expect(find.byType(MealGroupScreen), findsOneWidget);
      expect(find.byType(MealDetailScreen), findsNothing);

      // With the others gone it is one item again, and opens as one.
      await tester.tap(find.byType(AppBarBackButton));
      await tester.pumpAndSettle();
      nutrition.deleteMeals(['冰奶茶']);
      await tester.pumpAndSettle();
      await openRow('蛋餅');
      expect(find.byType(MealDetailScreen), findsOneWidget);
      expect(find.byType(MealGroupScreen), findsNothing);
      await disposeTree(tester);
    },
  );

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

  testWidgets('a night of time in bed is not measured against the sleep goal', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = emptyDay();
    store.backend.sleep.setGoal(const Duration(hours: 8));
    final morning = store.now().subtract(const Duration(hours: 2));
    JournalRepository(store.backend.db).addSleep(
      SleepEntry(
        id: 'in-bed',
        sleptAt: morning,
        duration: const Duration(hours: 8, minutes: 10),
        startedAt: morning.subtract(const Duration(hours: 8, minutes: 10)),
        measure: SleepMeasure.inBed,
      ),
      source: ChangeSource.healthKit,
    );
    await pumpScreen(tester, const TodayScreen(), store: store);

    expect(find.text('8 小時 10 分'), findsOneWidget);
    expect(find.text('在床時間'), findsOneWidget);
    expect(find.textContaining('目標'), findsNothing);
    expect(find.byType(ProgressLine), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('Today opens the bath page, with the last bath on its row', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = emptyDay();
    store.backend.journal.recordBath(
      at: store.now(),
      water: BathWater.warm,
      kind: BathKind.bath,
    );
    await pumpScreen(tester, const TodayScreen(), store: store);

    final row = find.widgetWithText(NavCard, '洗澡');
    expect(
      find.descendant(of: row, matching: find.textContaining('溫水')),
      findsOneWidget,
    );
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(BathScreen), findsOneWidget);
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
    // Would time out if the water kept moving.
    await tester.pumpAndSettle();
    expect(
      tester.hasRunningAnimations,
      isFalse,
      reason: 'it settles rather than redrawing forever',
    );

    store.backend.nutrition.logWater(250);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.hasRunningAnimations,
      isTrue,
      reason: 'a glass logged sets the water moving',
    );
    await tester.pumpAndSettle();
    await disposeTree(tester);

    store.backend.nutrition.setWaterReferenceMl(null);
    await pumpScreen(tester, const TodayScreen(), store: store);
    expect(find.text('1,250 mL', findRichText: true), findsOneWidget);
    expect(find.byType(LevelFill), findsNothing, reason: 'no reference');
    await disposeTree(tester);
  });

  testWidgets('energy eaten reads against its target on a bar', (tester) async {
    usePhoneViewport(tester);
    final store = emptyDay();
    store.backend.journal
      ..setSex(Sex.male)
      ..setBirthYear(1996)
      ..recordBodyReadings({BodyMetric.height: 175})
      ..recordWeight(70, at: store.now().subtract(const Duration(hours: 5)));
    store.backend.nutrition.logMeal(
      const MealEvent(
        id: 'lunch',
        name: '午餐',
        timeLabel: '12:00',
        qualityTag: '手動',
        dishes: [],
        kcal: 600,
      ),
      eatenAt: store.now(),
    );
    final target = store.backend.nutrition.targetsOn(store.now()).kcal!;
    await pumpScreen(tester, const TodayScreen(), store: store);

    final card = find.byType(IntakeCard);
    expect(
      find.textContaining('/ ${formatKcal(target)}', findRichText: true),
      findsOneWidget,
    );
    final bar = tester.widget<ProgressLine>(
      find.descendant(of: card, matching: find.byType(ProgressLine)),
    );
    expect(bar.progress, 600 / target);
    await disposeTree(tester);
  });

  testWidgets('sections follow the order set, and can show empty', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = emptyDay();
    final layout = TodayViewModel(store.backend);
    addTearDown(layout.dispose);
    expect(layout.showsOnlyWithData, isTrue, reason: 'by default');

    // 飲食 to the top.
    layout.move(layout.order.indexOf(TodaySection.intake), 0);
    expect(layout.order.first, TodaySection.intake);
    expect(layout.order, containsAll(TodaySection.values), reason: 'all kept');

    layout.setShowsOnlyWithData(false);
    await pumpScreen(tester, const TodayScreen(), store: store);
    final empty = find.byType(EmptySectionCard);
    expect(empty, findsWidgets, reason: 'nothing eaten, still in place');
    final intake = find.descendant(of: empty.first, matching: find.text('飲食'));
    expect(intake, findsOneWidget, reason: 'first, as ordered');

    await tester.tap(intake);
    await tester.pumpAndSettle();
    expect(
      find.byType(DailyNutritionScreen),
      findsOneWidget,
      reason: 'empty, it still opens the day',
    );
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
