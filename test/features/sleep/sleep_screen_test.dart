import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/sleep/sleep_screen.dart';
import 'package:mishirube/features/trends/trend_detail_screen.dart';
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
    expect(find.text('深層 · 3:06 · 40%'), findsOneWidget);
    final deep = tester
        .widgetList<ShareBar>(find.byType(ShareBar))
        .firstWhere((bar) => bar.share > 0.39 && bar.share < 0.41);
    expect(deep.reference, closeTo(102 / 465, 0.001));
    expect(
      find.textContaining('清醒 · 0:15'),
      findsOneWidget,
      reason: 'time awake has its minutes but no share of time asleep',
    );
    expect(find.textContaining('清醒 · 0:15 ·'), findsNothing);
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
      find.text('平均 7:45 · 3 晚'),
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
}
