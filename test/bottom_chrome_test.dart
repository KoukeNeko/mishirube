import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/features/shell/bottom_chrome/chrome_metrics.dart';
import 'package:mishirube/features/shell/bottom_chrome/quick_log_menu.dart';
import 'package:mishirube/features/shell/bottom_chrome/split_dock.dart';

import 'support/harness.dart';

const _settle = Duration(milliseconds: 600);
const _centerAction = ValueKey('dock-center-action');

/// The scroll view of the tab that is on screen (the others sit offstage in
/// the IndexedStack).
final _visibleScrollView = find.byType(CustomScrollView).hitTestable();

Future<AppStore> _pumpApp(WidgetTester tester, FakeClock clock) async {
  usePhoneViewport(tester);
  final store = AppStore(clock: clock.now, isOnboarded: true);
  await tester.pumpWidget(MishirubeApp(store: store));
  await tester.pump();
  return store;
}

Future<void> _settleFor(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(_settle);
}

void main() {
  testWidgets('dock switches tabs', (tester) async {
    final store = await _pumpApp(tester, FakeClock());

    await tester.tap(find.bySemanticsLabel('紀錄'));
    await _settleFor(tester);

    expect(store.selectedTab, HomeTab.log);
    await disposeTree(tester);
  });

  testWidgets('selected tab uses a filled icon and no indicator pill', (
    tester,
  ) async {
    await _pumpApp(tester, FakeClock());

    expect(find.byIcon(Icons.my_location), findsOneWidget);
    expect(find.byIcon(Icons.list_alt_outlined), findsOneWidget);
    final pill = find.descendant(
      of: find.byType(SplitDock),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color ==
                AppColors.trainingSurface,
      ),
    );
    expect(pill, findsNothing);
    await disposeTree(tester);
  });

  testWidgets('tab ripple is confined to the indicator pill', (tester) async {
    final store = await _pumpApp(tester, FakeClock());

    Future<void> expectInkOnPill(IconData icon) async {
      final inkFinder = find.descendant(
        of: find.bySemanticsLabel('紀錄'),
        matching: find.byType(InkWell),
      );
      final inkWell = tester.widget<InkWell>(inkFinder);
      final inkBounds = inkWell.customBorder!
          .getOuterPath(tester.getRect(inkFinder))
          .getBounds();
      final iconRect = tester.getRect(find.byIcon(icon));

      expect(inkBounds.size, const Size(56, 30));
      expect(inkBounds.center.dx, closeTo(iconRect.center.dx, 0.5));
      expect(inkBounds.center.dy, closeTo(iconRect.center.dy, 0.5));
      expect(tester.getRect(inkFinder).contains(inkBounds.topLeft), isTrue);
      expect(tester.getRect(inkFinder).contains(inkBounds.bottomRight), isTrue);
    }

    await expectInkOnPill(Icons.list_alt_outlined);

    store.selectTab(HomeTab.log);
    await _settleFor(tester);
    await tester.drag(_visibleScrollView, const Offset(0, -300));
    await _settleFor(tester);
    await expectInkOnPill(Icons.list_alt);
    await disposeTree(tester);
  });

  testWidgets('「+」opens the quick-log menu and × closes it', (tester) async {
    await _pumpApp(tester, FakeClock());

    await tester.tap(find.byKey(_centerAction));
    await _settleFor(tester);
    for (final label in ['訓練', '一餐', '體重與量測', '睡眠', '更多紀錄類型']) {
      expect(
        find.descendant(
          of: find.byKey(quickLogMenuKey),
          matching: find.text(label),
        ),
        findsOneWidget,
        reason: label,
      );
    }

    await tester.tap(find.byTooltip('關閉'));
    await _settleFor(tester);
    expect(find.text('更多紀錄類型'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('「更多紀錄類型」falls back to the full sheet', (tester) async {
    await _pumpApp(tester, FakeClock());

    await tester.tap(find.byKey(_centerAction));
    await _settleFor(tester);
    await tester.tap(find.text('更多紀錄類型'));
    await _settleFor(tester);

    expect(find.text('要記錄什麼？'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('workout accessory ticks, pauses and resumes', (tester) async {
    final clock = FakeClock();
    final store = await _pumpApp(tester, clock);
    store.startWorkout();
    await _settleFor(tester);
    expect(find.text('訓練進行中 · 0:00'), findsOneWidget);

    clock.advance(const Duration(seconds: 65));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('訓練進行中 · 1:05'), findsOneWidget);

    await tester.tap(find.byTooltip('暫停訓練'));
    clock.advance(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('已暫停 · 1:05'), findsOneWidget);

    await tester.tap(find.byTooltip('繼續訓練'));
    clock.advance(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('訓練進行中 · 1:15'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('scrolling down folds the accessory into a centre timer', (
    tester,
  ) async {
    final store = await _pumpApp(tester, FakeClock());
    store
      ..startWorkout()
      ..selectTab(HomeTab.log);
    await _settleFor(tester);
    expect(find.textContaining('訓練進行中 ·'), findsOneWidget);

    await tester.drag(_visibleScrollView, const Offset(0, -300));
    await _settleFor(tester);
    expect(find.textContaining('訓練進行中 ·'), findsNothing);
    expect(find.text('0:00'), findsOneWidget, reason: 'centre timer capsule');

    await tester.drag(_visibleScrollView, const Offset(0, 200));
    await _settleFor(tester);
    expect(find.textContaining('訓練進行中 ·'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('stop asks for confirmation, then shows the summary', (
    tester,
  ) async {
    final store = await _pumpApp(tester, FakeClock());
    store.startWorkout();
    await _settleFor(tester);

    await tester.tap(find.byTooltip('結束訓練'));
    await _settleFor(tester);
    expect(find.text('結束這次訓練？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '結束'));
    await _settleFor(tester);
    expect(store.activeWorkout, isNull);
    expect(find.text('回到今天'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('Reduce Motion turns chrome animations off', (tester) async {
    late Duration duration;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            duration = chromeDuration(context, ChromeMetrics.morphDuration);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(duration, Duration.zero);
  });

  testWidgets('iOS Reduce Motion also turns chrome animations off', (
    tester,
  ) async {
    // iOS reports Reduce Motion without setting disableAnimations.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    late Duration duration;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          duration = chromeDuration(context, ChromeMetrics.morphDuration);
          return const SizedBox.shrink();
        },
      ),
    );

    expect(duration, Duration.zero);
  });

  test('paused time is excluded from workout duration', () {
    final clock = FakeClock();
    final store = AppStore(clock: clock.now, isOnboarded: true)..startWorkout();

    clock.advance(const Duration(minutes: 10));
    store.togglePause();
    clock.advance(const Duration(minutes: 3));
    store.togglePause();
    clock.advance(const Duration(minutes: 2));
    store.finishWorkout();

    final workout = store.lastFinishedWorkout!;
    expect(workout.elapsedAt(clock.now()), const Duration(minutes: 12));
  });
}
