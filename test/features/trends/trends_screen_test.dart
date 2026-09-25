import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:flutter/material.dart';
import 'package:mishirube/features/trends/trends_screen.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('an insight without the records says what it needs', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const TrendsScreen(), store: store);

    expect(find.text('體重與飲食'), findsOneWidget);
    expect(find.text('能量平衡'), findsOneWidget);
    expect(find.textContaining('需要近 21 天有 14 天完整飲食'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('every area logged has a long-run row, even without records', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const TrendsScreen(), store: store);

    for (final area in ['身體', '訓練', '睡眠', '飲食', '活動']) {
      final row = find.widgetWithText(NavRow, area);
      await tester.dragUntilVisible(
        row,
        find.byType(CustomScrollView).hitTestable().first,
        const Offset(0, -200),
      );
      expect(row, findsOneWidget, reason: area);
    }
    await disposeTree(tester);
  });
}
