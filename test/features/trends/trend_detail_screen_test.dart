import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/engines/trend_findings.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/trends/trend_detail_screen.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import '../../support/harness.dart';

void main() {
  /// A store with only [nights] of sleep, ending last night, and a goal.
  AppStore sleeper(List<int> hours, {Duration? goal}) {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.provenance.setShowsDemo(false);
    final now = store.now();
    for (final (back, length) in hours.indexed) {
      final woke = DateTime(now.year, now.month, now.day - back, 7);
      store.backend.journal.recordSleep(
        Duration(hours: length),
        at: woke,
        startedAt: woke.subtract(Duration(hours: length)),
      );
    }
    store.backend.sleep.setGoal(goal);
    return store;
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );

  testWidgets('sleep says its figures and how the nights spread', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = sleeper([
      6,
      7,
      8,
      9,
      7,
      7,
      8,
    ], goal: const Duration(hours: 8));
    await pumpScreen(
      tester,
      const TrendDetailScreen(domain: TrendDomain.sleep),
      store: store,
    );

    expect(
      find.text('資料不足，暫不比較 · 7/28 天有紀錄'),
      findsOneWidget,
      reason: 'a week of nights is not four weeks to compare',
    );

    await scrollTo(tester, find.byType(FigureGrid));
    final figures = tester.widget<FigureGrid>(find.byType(FigureGrid)).figures;
    String valueOf(String label) =>
        figures.firstWhere((figure) => figure.label.startsWith(label)).value;
    expect(valueOf('平均睡著時間'), '7:26');
    expect(valueOf('半數晚上超過'), '7:00');
    expect(valueOf('最長'), '9:00');
    expect(valueOf('最短'), '6:00');
    expect(valueOf('達成睡眠目標'), '7 晚中 3 晚');
    // Waking at seven every day, asleep from 22:00 to 01:00: an average
    // of 23:34, most nights within 54 minutes of it.
    expect(valueOf('平常入睡'), '22:40–00:28');
    expect(valueOf('平常起床'), '07:00–07:00');

    await scrollTo(tester, find.byType(DistributionChart));
    expect(
      tester.widget<DistributionChart>(find.byType(DistributionChart)).counts,
      [0, 1, 3, 2, 1],
      reason: '6, then 7 7 7, 8 8, 9 hours',
    );
    await disposeTree(tester);
  });

  testWidgets('a few nights are figures, not yet a spread', (tester) async {
    usePhoneViewport(tester);
    final store = sleeper([7, 8]);
    await pumpScreen(
      tester,
      const TrendDetailScreen(domain: TrendDomain.sleep),
      store: store,
    );

    await scrollTo(tester, find.byType(FigureGrid));
    final labels = [
      for (final figure
          in tester.widget<FigureGrid>(find.byType(FigureGrid)).figures)
        figure.label,
    ];
    expect(
      labels.any((label) => label.startsWith('達成睡眠目標')),
      isFalse,
      reason: 'no goal set',
    );
    expect(find.byType(DistributionChart), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('training reads its weeks against the weekly goal', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.goal
      ..setEnabled(true)
      ..setGoal(3, applyThisWeek: true);
    await pumpScreen(
      tester,
      const TrendDetailScreen(domain: TrendDomain.training),
      store: store,
    );

    final chart = find.byType(GoalWeeksChart);
    expect(chart, findsOneWidget);
    final weeks = tester.widget<GoalWeeksChart>(chart);
    expect(weeks.goal, 3);
    expect(weeks.met, {
      for (final (index, days) in weeks.values.indexed)
        if (days != null && days >= 3) index,
    }, reason: 'a check on every week of three days or more');

    await scrollTo(tester, find.byType(FigureGrid));
    final labels = [
      for (final figure
          in tester.widget<FigureGrid>(find.byType(FigureGrid)).figures)
        figure.label,
    ];
    expect(labels, containsAll(['訓練次數', '每週平均', '達成每週目標']));

    await scrollTo(tester, find.text('動作'));
    expect(
      find.descendant(
        of: find.byType(GroupedCard),
        matching: find.textContaining(' 組'),
      ),
      findsWidgets,
      reason: 'the most trained exercises, with their sets',
    );
    await disposeTree(tester);
  });

  testWidgets('without a weekly goal there is no goal chart', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(
      tester,
      const TrendDetailScreen(domain: TrendDomain.training),
      store: store,
    );
    expect(find.byType(GoalWeeksChart), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('food says how many logged days were complete', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.provenance.setShowsDemo(false);
    final now = store.now();
    // Three full days and one with only breakfast.
    for (final (back, meals) in [(1, 3), (2, 3), (3, 3), (4, 1)]) {
      final day = DateTime(now.year, now.month, now.day - back);
      for (var meal = 0; meal < meals; meal++) {
        store.backend.nutrition.logMeal(
          MealEvent(
            id: '$back-$meal',
            name: '一餐',
            timeLabel: '',
            qualityTag: '手動',
            dishes: const [],
            kcal: 700,
          ),
          eatenAt: day.add(Duration(hours: 8 + meal * 5)),
        );
      }
    }
    await pumpScreen(
      tester,
      const TrendDetailScreen(domain: TrendDomain.nutrition),
      store: store,
    );

    await scrollTo(tester, find.byType(FigureGrid));
    final figures = tester.widget<FigureGrid>(find.byType(FigureGrid)).figures;
    expect(
      figures.firstWhere((figure) => figure.label == '紀錄天數').value,
      '4 天中 3 天完整',
    );
    expect(
      figures.firstWhere((figure) => figure.label == '每日平均').value,
      '2,100',
      reason: 'the complete days only',
    );
    await disposeTree(tester);
  });

  testWidgets('sixteen weeks of nights read against the usual range', (
    tester,
  ) async {
    usePhoneViewport(tester);
    // Seven hours a night for twelve weeks, then eight for four.
    final store = sleeper([
      for (var back = 0; back < 16 * 7; back++) back < 28 ? 8 : 7,
    ]);
    await pumpScreen(
      tester,
      const TrendDetailScreen(domain: TrendDomain.sleep),
      store: store,
    );
    expect(find.text('比平常多 · 每晚 +60 分'), findsOneWidget);
    await disposeTree(tester);
  });
}
