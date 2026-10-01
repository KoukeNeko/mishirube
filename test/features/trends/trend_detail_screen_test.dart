import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/engines/trend_findings.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/sleep/sleep_regularity_card.dart';
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
    expect(valueOf('平均睡著時間'), '7 小時 26 分');
    expect(valueOf('半數晚上超過'), '7 小時');
    expect(valueOf('最長'), '9 小時');
    expect(valueOf('最短'), '6 小時');
    expect(valueOf('達成睡眠目標'), '7 晚中 3 晚');
    expect(
      figures.any((figure) => figure.label == '平常入睡'),
      isFalse,
      reason: 'bedtimes are the schedule chart\'s, not the grid\'s',
    );
    expect(
      find.byType(SleepRegularityCard),
      findsNothing,
      reason: 'the last four weeks\' regularity is the sleep page\'s',
    );

    // Waking at seven every day, asleep from 22:00 to 01:00: the week's
    // nights begin at 23:34 on average and last 7:26, so end at 07:00.
    await scrollTo(tester, find.byType(RangeBarChart));
    final (bedtime, wake) = tester
        .widget<RangeBarChart>(find.byType(RangeBarChart))
        .ranges
        .last!;
    expect(bedtime, closeTo(11 * 60 + 34, 1));
    expect(wake, closeTo(19 * 60, 1));

    final goalWeeks = tester.widget<MiniBarChart>(
      find.byWidgetPredicate(
        (widget) => widget is MiniBarChart && widget.top == 7,
      ),
    );
    expect(goalWeeks.bars.last.$2, 3, reason: '8, 9 and 8 hours meet 8');
    expect(goalWeeks.bars.first.$2, isNull, reason: 'no nights that week');

    await scrollTo(tester, find.byType(DistributionChart));
    expect(
      tester.widget<DistributionChart>(find.byType(DistributionChart)).counts,
      [0, 1, 3, 2, 1],
      reason: '6, then 7 7 7, 8 8, 9 hours',
    );
    await disposeTree(tester);
  });

  testWidgets('six ranges fit a phone, each label on one line', (tester) async {
    usePhoneViewport(tester);
    await pumpScreen(
      tester,
      const TrendDetailScreen(domain: TrendDomain.sleep),
      store: sleeper([7]),
    );

    Rect chip(String label) => tester.getRect(
      find
          .ancestor(of: find.text(label), matching: find.byType(Material))
          .first,
    );
    final week = chip('週');
    for (final label in ['月', '3 個月', '6 個月', '1 年', '全部']) {
      expect(chip(label).height, week.height, reason: '$label on one line');
    }
    expect(chip('全部').right, lessThanOrEqualTo(tester.view.physicalSize.width));
    await disposeTree(tester);
  });

  testWidgets('bedtimes across a new year give the chart\'s ends their year', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = sleeper([7, 8, 7]);
    await pumpScreen(
      tester,
      const TrendDetailScreen(domain: TrendDomain.sleep),
      store: store,
    );

    RangeBarChart chart() =>
        tester.widget<RangeBarChart>(find.byType(RangeBarChart));
    await tester.scrollUntilVisible(
      find.byType(RangeBarChart),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(chart().start, isNot(contains('年')), reason: 'six months in 2026');

    await tester.scrollUntilVisible(
      find.text('1 年'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('1 年'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(RangeBarChart),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(chart().start, startsWith('2025年'));
    expect(chart().end, startsWith('2026年'));
    await disposeTree(tester);
  });

  testWidgets('a weekday reads out when touched', (tester) async {
    usePhoneViewport(tester);
    await pumpScreen(
      tester,
      const TrendDetailScreen(domain: TrendDomain.sleep),
      store: sleeper([6, 7, 8, 9, 7, 7, 8]),
    );

    final chart = find.byWidgetPredicate(
      (widget) => widget is MiniBarChart && widget.bars.first.$1 == '一',
    );
    await tester.scrollUntilVisible(
      chart,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(chart), alignment: 0.5);
    await tester.pumpAndSettle();
    expect(find.textContaining('最高'), findsOneWidget);

    await tester.tapAt(tester.getRect(chart).centerLeft + const Offset(4, 0));
    await tester.pump();
    expect(find.textContaining('星期一 '), findsOneWidget);
    expect(find.textContaining('最高'), findsNothing);
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
