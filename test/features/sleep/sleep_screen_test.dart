import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/sleep/sleep_schedule_chart.dart';
import 'package:mishirube/features/sleep/sleep_screen.dart';
import 'package:mishirube/features/trends/trend_detail_screen.dart';
import 'package:mishirube/backend/engines/trend_findings.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import '../../support/harness.dart';

void main() {
  /// A store with a staged night ending on each of the last [nights]
  /// mornings: 15 minutes in bed awake, then core and deep sleep, the
  /// last night with [deep] minutes of deep sleep and the others 90.
  AppStore staged(int nights, {required int deep}) {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.provenance.setShowsDemo(false);
    final now = store.now();
    for (var back = 0; back < nights; back++) {
      final woke = DateTime(now.year, now.month, now.day - back, 7);
      final start = woke.subtract(const Duration(hours: 8));
      final deepMinutes = back == 0 ? deep : 90;
      SleepSample stretch(SleepStage stage, int from, int to) => SleepSample(
        start: start.add(Duration(minutes: from)),
        end: start.add(Duration(minutes: to)),
        stage: stage,
        source: 'watch',
      );
      store.backend.storage.journal
        ..addSleep(
          SleepEntry(
            id: 'night-$back',
            sleptAt: woke,
            duration: const Duration(minutes: 465),
            startedAt: start,
          ),
          source: ChangeSource.healthKit,
        )
        ..replaceSleepSegments('night-$back', [
          stretch(SleepStage.awake, 0, 15),
          stretch(SleepStage.core, 15, 480 - deepMinutes),
          stretch(SleepStage.deep, 480 - deepMinutes, 480),
        ], source: ChangeSource.healthKit);
    }
    return store;
  }

  testWidgets('each stage is set against the usual night\'s share', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await pumpScreen(tester, const SleepScreen(), store: staged(8, deep: 186));

    final legend = find.text('近 30 天平均 · 8 晚');
    await tester.scrollUntilVisible(
      legend,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // 465 minutes asleep: deep 186 is 40%; the usual deep night is 90
    // minutes seven times and 186 once, 102 of 465.
    expect(find.text('深層 · 3 小時 6 分 · 40%'), findsOneWidget);
    final deep = tester
        .widgetList<ShareBar>(find.byType(ShareBar))
        .firstWhere((bar) => bar.share > 0.39 && bar.share < 0.41);
    expect(deep.reference, closeTo(102 / 465, 0.001));
    expect(
      find.textContaining('清醒 · 15 分'),
      findsOneWidget,
      reason: 'time awake has its minutes but no share of time asleep',
    );
    expect(find.textContaining('清醒 · 15 分 ·'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('a few staged nights are not yet called usual', (tester) async {
    usePhoneViewport(tester);
    await pumpScreen(tester, const SleepScreen(), store: staged(3, deep: 90));

    await tester.scrollUntilVisible(
      find.byType(ShareBar).first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widgetList<ShareBar>(find.byType(ShareBar))
          .every((bar) => bar.reference == null),
      isTrue,
    );
    expect(find.textContaining('近 30 天平均'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('the page holds its day; the header opens the sleep trend, '
      'which reads nights from a week up and also shows the debt', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await pumpScreen(tester, const SleepScreen(), store: staged(3, deep: 90));

    await tester.scrollUntilVisible(
      find.text('刪除這筆紀錄'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('作息規律', skipOffstage: false), findsNothing);
    expect(find.text('影響因素', skipOffstage: false), findsNothing);
    await tester.tap(find.bySemanticsLabel('睡眠趨勢'));
    await tester.pumpAndSettle();
    expect(find.byType(TrendDetailScreen), findsOneWidget);

    await tester.tap(find.text('週'));
    await tester.pumpAndSettle();
    expect(
      find.text('平均 7 小時 45 分 · 3 晚'),
      findsOneWidget,
      reason: 'a week reads night by night',
    );
    for (final section in ['睡眠債', '作息規律']) {
      await tester.scrollUntilVisible(
        find.text(section),
        200,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await disposeTree(tester);
  });

  testWidgets('over months the stages are read week by week, a month '
      'night by night', (tester) async {
    usePhoneViewport(tester);
    await pumpScreen(
      tester,
      const TrendDetailScreen(domain: TrendDomain.sleep),
      store: staged(220, deep: 90),
    );
    final deep = find.byWidgetPredicate(
      (widget) => widget is UsualRangeTrend && widget.label == '深層',
    );
    await tester.scrollUntilVisible(
      deep,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    var trend = tester.widget<UsualRangeTrend>(deep);
    expect(trend.days, hasLength(26), reason: 'six months, one point a week');
    expect(trend.summary, '平均 1 小時 30 分 · 182 晚');
    expect(
      trend.bands.last,
      isNotNull,
      reason: 'the latest week has 13 weeks of nights before it',
    );

    // The picked week's range is named by the band's key, not squeezed
    // into the reading line.
    final chart = find.descendant(of: deep, matching: find.byType(Sparkline));
    await Scrollable.ensureVisible(tester.element(chart), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getCenter(chart) + Offset(tester.getSize(chart).width / 2 - 1, 0),
    );
    await tester.pump();
    expect(find.textContaining(' 起 · 1 小時 30 分'), findsOneWidget);
    expect(find.text('平常 1 小時 30 分–1 小時 30 分'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('月'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('月')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      deep,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    trend = tester.widget<UsualRangeTrend>(deep);
    expect(trend.days, hasLength(30));
    expect(trend.summary, '平均 1 小時 30 分 · 30 晚');
    await disposeTree(tester);
  });

  testWidgets('a target schedule is drawn on the nights as lines', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = staged(3, deep: 90);
    await pumpScreen(
      tester,
      const TrendDetailScreen(domain: TrendDomain.sleep),
      store: store,
    );
    await tester.tap(find.text('週'));
    await tester.pumpAndSettle();
    final chart = find.byType(SleepScheduleChart);
    await tester.scrollUntilVisible(
      chart.first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.widget<SleepScheduleChart>(chart.first).targets,
      isEmpty,
      reason: 'none until the user sets one',
    );

    store.backend.sleep
      ..setTargetBedtime(23 * 60)
      ..setTargetWake(7 * 60);
    await tester.pumpAndSettle();
    expect(tester.widget<SleepScheduleChart>(chart.first).targets, [
      23 * 60,
      7 * 60,
    ]);
    expect(find.text('目標作息'), findsWidgets);
    await disposeTree(tester);
  });
}
