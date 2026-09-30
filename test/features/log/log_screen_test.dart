import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/features/log/month_calendar.dart';
import 'package:mishirube/shared/widgets/widgets.dart';
import 'package:mishirube/shared/window_layout.dart';

import '../../support/harness.dart';

import 'package:mishirube/l10n/l10n.dart';

/// The calendar's pinned month reading [text], not a month's own label in
/// the calendar.
/// The month on the button at the top left, which is the calendar's
/// title.
Finder _title(String text) =>
    find.descendant(of: find.byType(HeaderAction), matching: find.text(text));

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

  testWidgets('the weekdays stay put on switching to the calendar', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(MishirubeApp(store: storeWithNotes()));
    await tester.pumpAndSettle();
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    // The strip's week, not the weeks either side showing in the margins.
    Offset weekday(String text) => find
        .text(text)
        .evaluate()
        .map((element) => tester.getTopLeft(find.byWidget(element.widget)))
        .firstWhere((at) => at.dx > 0 && at.dx < width);
    final onTimeline = [weekday('一'), weekday('日')];

    await openCalendar(tester);
    expect([weekday('一'), weekday('日')], onTimeline);
    await disposeTree(tester);
  });

  testWidgets('a day picked on the week strip scrolls the timeline to it', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final clock = FakeClock();
    final store = AppStore(
      clock: clock.now,
      isOnboarded: true,
      backend: Backend.inMemory(clock: clock.now),
    )..selectTab(HomeTab.log);
    // Enough days that the 14th starts below the screen.
    for (var day = 14; day <= 19; day++) {
      for (var hour = 8; hour < 14; hour++) {
        store.backend.journal.recordNote(
          '$day 號 $hour 點',
          at: DateTime(2026, 9, day, hour),
        );
      }
    }
    await tester.pumpWidget(MishirubeApp(store: store));
    await tester.pumpAndSettle();
    final note = find.text('14 號 13 點');
    expect(note.hitTestable(), findsNothing, reason: 'further down');

    final strip = find.byType(WeekDayStrip);
    await tester.tap(
      find.descendant(of: strip, matching: find.text('14')).hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(note.hitTestable(), findsOneWidget);
    expect(
      tester.getRect(note).top,
      greaterThan(tester.getRect(strip).bottom),
      reason: 'under the pinned strip, not behind it',
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.selected == true &&
            (widget.properties.label?.contains('14') ?? false),
      ),
      findsOneWidget,
      reason: 'the strip still has the day picked once the list stops',
    );
    await disposeTree(tester);
  });

  testWidgets(
    'the week strip ticks per day, swiped or turned to',
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    (tester) async {
      usePhoneViewport(tester);
      final haptics = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(MishirubeApp(store: storeWithNotes()));
      await tester.pumpAndSettle();

      final strip = find.byType(WeekDayStrip);
      // Slowly, a frame at a time, so no day is skipped in one frame.
      final gesture = await tester.startGesture(tester.getCenter(strip));
      final week =
          tester.getSize(strip).width -
          PageColumn.gutterOf(tester.element(strip)).horizontal;
      for (var moved = 0.0; moved < week; moved += 8) {
        await gesture.moveBy(const Offset(8, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        haptics.where((type) => type == 'HapticFeedbackType.selectionClick'),
        hasLength(7),
        reason: 'a day at a time, as the Digital Crown',
      );
      expect(haptics.last, 'HapticFeedbackType.lightImpact', reason: 'settled');

      // Turned back to today's week by the app, it ticks the same.
      haptics.clear();
      await tester.tap(find.text('今天').hitTestable().first);
      await tester.pumpAndSettle();
      expect(
        haptics.where((type) => type == 'HapticFeedbackType.selectionClick'),
        isNotEmpty,
        reason: 'the row moved, so the hand feels it',
      );
      expect(haptics.last, 'HapticFeedbackType.lightImpact', reason: 'settled');
      await disposeTree(tester);
    },
  );

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
    expect(_title('2026年8月'), findsOneWidget, reason: 'scrolled back');
    expect(find.text('9月19日 週六'), findsOneWidget, reason: 'the day stays');

    await tester.tap(find.bySemanticsLabel('回到今天').hitTestable());
    await tester.pumpAndSettle();
    expect(_title('2026年9月'), findsOneWidget);

    // Still there once the page has scrolled on to the day's records.
    await tester.drag(find.byType(CategoryLabel).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(_title('2026年9月').hitTestable(), findsOneWidget, reason: 'pinned');
    await disposeTree(tester);
  });

  testWidgets('a week starts on the day the device is set to', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              const WeekdayHeader(firstWeekday: DateTime.sunday),
              MonthCalendar(
                month: DateTime(2026, 9),
                earliest: DateTime(2026, 9),
                selected: DateTime(2026, 9, 19),
                today: DateTime(2026, 9, 19),
                firstWeekday: DateTime.sunday,
                categoriesOf: (_) => const {},
                onSelect: (_) {},
                onMonth: (_) {},
              ),
            ],
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
      tester.getCenter(find.text('二')).dx,
      closeTo(tester.getCenter(find.text('1')).dx, 1),
      reason: 'each weekday over its column',
    );
    expect(
      tester.getCenter(find.text('1')).dx,
      closeTo(
        AppSpacing.screenGutter +
            (width - AppSpacing.screenGutter * 2) / 7 * 2.5,
        1,
      ),
      reason:
          'September 1st, a Tuesday, in the third column of the page '
          "column, as the timeline's week strip has it",
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
