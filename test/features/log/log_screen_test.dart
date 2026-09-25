import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/features/log/month_calendar.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import '../../support/harness.dart';

/// The calendar's pinned month reading [text], not a month's own label in
/// the calendar.
Finder _title(String text) => find.byWidgetPredicate(
  (widget) =>
      widget is Text && widget.data == text && widget.style == largeTitleStyle,
);

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

  testWidgets('the calendar scrolls through months, the month following', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(MishirubeApp(store: storeWithNotes()));
    await tester.pumpAndSettle();
    await openCalendar(tester);

    // Less than August's weeks: August reaches the top, July does not.
    await tester.drag(find.byType(MonthCalendar), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(_title('8月'), findsOneWidget, reason: 'scrolled back');
    expect(find.text('2026年'), findsOneWidget, reason: 'its year, top left');
    expect(find.text('9月19日 週六'), findsOneWidget, reason: 'the day stays');

    await tester.tap(find.bySemanticsLabel('回到今天').hitTestable());
    await tester.pumpAndSettle();
    expect(_title('9月'), findsOneWidget);

    // Still there once the page has scrolled on to the day's records.
    await tester.drag(find.byType(CategoryLabel).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(_title('9月').hitTestable(), findsOneWidget, reason: 'pinned');
    await disposeTree(tester);
  });

  testWidgets('a week starts on the day the device is set to', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthCalendar(
            month: DateTime(2026, 9),
            earliest: DateTime(2026, 9),
            selected: DateTime(2026, 9, 19),
            today: DateTime(2026, 9, 19),
            firstWeekday: DateTime.sunday,
            categoriesOf: (_) => const {},
            onSelect: (_) {},
            onMonth: (_) {},
          ),
        ),
      ),
    );

    final width = tester.getSize(find.byType(MonthCalendar)).width;
    expect(
      tester.getCenter(find.text('日')).dx,
      lessThan(tester.getCenter(find.text('一')).dx),
      reason: 'Sunday first',
    );
    expect(
      tester.getCenter(find.text('1')).dx,
      closeTo(width / 7 * 2.5, 1),
      reason: 'September 1st, a Tuesday, in the third column',
    );
    expect(find.text('9月'), findsOneWidget, reason: 'written as the system');
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
        matching: find.text('18').hitTestable(),
      ),
    );
    await tester.pumpAndSettle();
    // Dragged by the day's heading: the calendar scrolls months itself.
    await tester.dragUntilVisible(
      find.text('十八號的筆記'),
      find.text('9月18日 週五'),
      const Offset(0, -200),
    );
    await tester.tap(find.text('十八號的筆記'));
    await tester.pumpAndSettle();
    expect(find.text('十八號的筆記'), findsWidgets, reason: 'its page opened');
    expect(find.byType(MonthCalendar).hitTestable(), findsNothing);
    await disposeTree(tester);
  });
}
