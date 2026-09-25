import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/features/log/month_calendar.dart';

import '../../support/harness.dart';

void main() {
  /// A note on the 2nd and the 18th of the demo's month (September 2026,
  /// today the 19th), each at noon.
  AppStore storeWithNotes() {
    final clock = FakeClock();
    final store = AppStore(
      clock: clock.now,
      isOnboarded: true,
      backend: Backend.inMemory(clock: clock.now),
    )..selectTab(HomeTab.log);
    for (final (day, text) in [(2, '二號的筆記'), (18, '十八號的筆記')]) {
      store.backend.journal.recordNote(text, at: DateTime(2026, 9, day, 12));
    }
    return store;
  }

  Future<void> openCalendar(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('以月曆顯示').hitTestable());
    await tester.pumpAndSettle();
  }

  testWidgets('the log opens on the view last chosen', (tester) async {
    usePhoneViewport(tester);
    final store = storeWithNotes();
    await tester.pumpWidget(MishirubeApp(store: store));
    await tester.pumpAndSettle();
    await openCalendar(tester);
    await disposeTree(tester);

    await tester.pumpWidget(MishirubeApp(store: store));
    await tester.pumpAndSettle();
    expect(find.byType(MonthCalendar), findsOneWidget, reason: 'kept');
    await disposeTree(tester);
  });

  testWidgets('the month steps back, and not past the current one', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(MishirubeApp(store: storeWithNotes()));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('下個月').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('2026 年 9 月'), findsOneWidget, reason: 'no future');

    await tester.tap(find.bySemanticsLabel('上個月').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('2026 年 8 月'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('下個月').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('2026 年 9 月'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('a day on the calendar lists its records, each opening', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = storeWithNotes();
    await tester.pumpWidget(MishirubeApp(store: store));
    await tester.pumpAndSettle();
    await openCalendar(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(MonthCalendar),
        matching: find.text('18'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('十八號的筆記'), 200);
    await tester.tap(find.text('十八號的筆記'));
    await tester.pumpAndSettle();
    expect(find.text('十八號的筆記'), findsWidgets, reason: 'its page opened');
    expect(find.byType(MonthCalendar).hitTestable(), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('opening a day on the timeline scrolls to it', (tester) async {
    usePhoneViewport(tester);
    final store = storeWithNotes();
    await tester.pumpWidget(MishirubeApp(store: store));
    await tester.pumpAndSettle();
    await openCalendar(tester);

    await tester.tap(
      find.descendant(of: find.byType(MonthCalendar), matching: find.text('2')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('在時間軸開啟'), 200);
    await tester.tap(find.text('在時間軸開啟'));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    expect(find.byType(MonthCalendar), findsNothing);
    expect(
      find.text('9 月 2 日（週三）').hitTestable(),
      findsOneWidget,
      reason: 'the timeline is on the 2nd, far below today',
    );
    await disposeTree(tester);
  });
}
