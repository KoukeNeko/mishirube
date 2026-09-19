import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/features/training/active_workout_screen.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import 'support/harness.dart';

const _settle = Duration(milliseconds: 600);
final _toolbarHeight = ToolbarMetrics.android.height;
final _visibleScrollView = find.byType(CustomScrollView).hitTestable();

Future<AppStore> _pumpApp(
  WidgetTester tester, {
  HomeTab tab = HomeTab.today,
}) async {
  usePhoneViewport(tester);
  final store = AppStore(clock: FakeClock().now, isOnboarded: true)
    ..selectTab(tab);
  await tester.pumpWidget(MishirubeApp(store: store));
  await tester.pump();
  return store;
}

Future<void> _scroll(WidgetTester tester, double dy) async {
  await tester.drag(_visibleScrollView, Offset(0, -dy));
  await tester.pump();
  await tester.pump(_settle);
}

/// Opacity applied to the text [label] by its nearest Opacity ancestor.
double _opacityOf(WidgetTester tester, Finder text) {
  final opacity = tester.widget<Opacity>(
    find.ancestor(of: text, matching: find.byType(Opacity)).first,
  );
  return opacity.opacity;
}

/// Only Today's header can hold these (other tabs sit at scroll 0).
Finder _inHeader(Finder finder) =>
    find.descendant(of: find.byType(SliverPersistentHeader), matching: finder);

/// Today's large title (other tabs' titles also exist, offstage).
Finder get _largeTitle => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is LargeTitleBlock && widget.title == '今天',
  ),
  matching: find.text('今天'),
);

void main() {
  testWidgets('large title collapses into a compact glass toolbar', (
    tester,
  ) async {
    await _pumpApp(tester);
    final semantics = tester.ensureSemantics();

    expect(find.text('9 月 19 日・週六・早上'), findsOneWidget);
    expect(_opacityOf(tester, _largeTitle), 1);
    expect(
      _inHeader(find.byType(BackdropFilter)),
      findsNothing,
      reason: 'no glass while nothing scrolls underneath',
    );

    await _scroll(tester, 400);

    expect(_opacityOf(tester, _largeTitle), 0);
    final compactTitle = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data == '今天' &&
          widget.style == compactTitleStyle,
    );
    expect(
      _opacityOf(tester, compactTitle),
      1,
      reason: 'compact title fully visible once collapsed',
    );
    expect(_inHeader(find.byType(BackdropFilter)), findsOneWidget);
    expect(
      find.bySemanticsLabel('今天').evaluate().length,
      lessThanOrEqualTo(2),
      reason: 'one header title plus the dock tab, never two titles',
    );
    semantics.dispose();
    await disposeTree(tester);
  });

  testWidgets('large title sits at the leading edge', (tester) async {
    await _pumpApp(tester);

    expect(tester.getRect(_largeTitle).left, AppSpacing.screenGutter);
    expect(
      tester.getRect(find.text('9 月 19 日・週六・早上')).left,
      AppSpacing.screenGutter,
    );
    await disposeTree(tester);
  });

  testWidgets('view switch stays pinned and auto-hide tucks the toolbar away', (
    tester,
  ) async {
    await _pumpApp(tester, tab: HomeTab.log);
    final pinnedTopBefore = tester.getRect(find.text('時間軸').hitTestable()).top;

    await _scroll(tester, 500);

    final pinnedTop = tester.getRect(find.text('時間軸').hitTestable()).top;
    expect(pinnedTop, lessThan(pinnedTopBefore));
    expect(
      pinnedTop,
      lessThan(phoneTopInset + _toolbarHeight),
      reason: 'toolbar row hidden while reading down',
    );
    expect(pinnedTop, greaterThanOrEqualTo(phoneTopInset));

    await _scroll(tester, -120);
    expect(
      tester.getRect(find.text('時間軸').hitTestable()).top,
      greaterThanOrEqualTo(phoneTopInset + _toolbarHeight),
      reason: 'scrolling back up brings the toolbar back',
    );
    await disposeTree(tester);
  });

  testWidgets('trends range control stays pinned', (tester) async {
    await _pumpApp(tester, tab: HomeTab.trends);

    await _scroll(tester, 600);

    expect(find.text('近 4 週').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('workout hero collapses into a live bar', (tester) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..startWorkout();
    await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);
    expect(find.text('0:00 · 槓鈴深蹲 1/5'), findsOneWidget);
    expect(_opacityOf(tester, find.text('0:00 · 槓鈴深蹲 1/5')), 0);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump();

    expect(_opacityOf(tester, find.text('0:00 · 槓鈴深蹲 1/5')), 1);
    expect(find.text('結束').hitTestable(), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('headers grow with 2x text instead of overflowing', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = await _pumpApp(tester);

    for (final tab in HomeTab.values) {
      store.selectTab(tab);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$tab expanded');
      await _scroll(tester, 400);
      expect(tester.takeException(), isNull, reason: '$tab collapsed');
    }
    await disposeTree(tester);

    final workoutStore = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..startWorkout();
    await pumpScreen(tester, const ActiveWorkoutScreen(), store: workoutStore);
    expect(tester.takeException(), isNull, reason: 'workout hero');
    await disposeTree(tester);
  });

  testWidgets('Reduce Motion swaps titles without a fade', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pumpApp(tester);

    await tester.drag(_visibleScrollView, const Offset(0, -20));
    await tester.pump();

    expect(_opacityOf(tester, _largeTitle), 1, reason: 'no partial fade');
    await disposeTree(tester);
  });

  testWidgets('Increase Contrast uses an opaque header', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(highContrast: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pumpApp(tester);

    await _scroll(tester, 400);

    expect(_inHeader(find.byType(BackdropFilter)), findsNothing);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });
}
