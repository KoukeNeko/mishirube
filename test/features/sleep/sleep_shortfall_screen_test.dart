import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/features/sleep/sleep_shortfall_screen.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('the debt reads over a month or more, and each night short', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.provenance.setShowsDemo(false);
    store.backend.sleep.setGoal(const Duration(hours: 8));
    final now = store.now();
    // Seven hours a night for the last 40 mornings, today's not yet in.
    for (var back = 1; back <= 40; back++) {
      final woke = DateTime(now.year, now.month, now.day - back, 7);
      store.backend.journal.recordSleep(
        const Duration(hours: 7),
        at: woke,
        startedAt: woke.subtract(const Duration(hours: 7)),
      );
    }
    await pumpScreen(tester, SleepShortfallScreen(day: now), store: store);

    final line = find.byType(Sparkline);
    await tester.scrollUntilVisible(
      line,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<Sparkline>(line).values, hasLength(30));
    expect(
      tester.widget<Sparkline>(line).values.last,
      14,
      reason: 'fourteen nights an hour short',
    );

    final nights = find.byType(MiniBarChart);
    await tester.scrollUntilVisible(
      nights,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final bars = tester.widget<MiniBarChart>(nights).bars;
    expect(bars, hasLength(30));
    expect(
      bars.last.$2,
      60,
      reason: 'last night, an hour short: today counts once its night is in',
    );

    await tester.scrollUntilVisible(
      find.text('3 個月'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('3 個月'));
    await tester.pumpAndSettle();
    expect(tester.widget<Sparkline>(line).values, hasLength(91));
    await disposeTree(tester);
  });
}
