import 'package:flutter/rendering.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/exercise/exercise_picker_screen.dart';
import 'package:mishirube/features/nutrition/food_search_screen.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/features/journal/weight_entry_screen.dart';
import 'package:mishirube/features/training/active_workout_screen.dart';
import 'package:mishirube/shared/widgets/widgets.dart';
import 'package:mishirube/shared/window_controls.dart';

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

/// The header's own scroll-edge glass (its action pills are glass too).
Finder get _headerGlass => _inHeader(
  find.descendant(
    of: find.byType(ScrollEdgeGlass),
    matching: find.byType(BackdropFilter),
  ),
);

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

    expect(find.text('9 月 19 日（週六）'), findsOneWidget);
    expect(_opacityOf(tester, _largeTitle), 1);
    expect(
      _headerGlass,
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
    expect(_headerGlass, findsOneWidget);
    expect(
      find.bySemanticsLabel('今天').evaluate().length,
      lessThanOrEqualTo(2),
      reason: 'one header title plus the dock tab, never two titles',
    );
    semantics.dispose();
    await disposeTree(tester);
  });

  testWidgets('the compact title is centred on the bar', (tester) async {
    await _pumpApp(tester);
    await _scroll(tester, 400);
    final compactTitle = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data == '今天' &&
          widget.style == compactTitleStyle,
    );

    expect(
      tester.getRect(compactTitle).center.dx,
      closeTo(phoneSize.width / 2, 0.5),
      reason: 'centred on the bar, not in the space left of the actions',
    );
    await disposeTree(tester);
  });

  testWidgets('a back control does not push the title off centre', (
    tester,
  ) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const WeightEntryScreen(), store: store);
    final title = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data == '體重' &&
          widget.style == compactTitleStyle,
    );

    expect(tester.getRect(title).center.dx, closeTo(phoneSize.width / 2, 0.5));
    expect(
      tester.getRect(find.bySemanticsLabel('返回')).left,
      lessThan(tester.getRect(title).left),
      reason: 'the back control keeps its place at the leading edge',
    );
    await disposeTree(tester);
  });

  testWidgets('large title sits at the leading edge', (tester) async {
    await _pumpApp(tester);

    expect(tester.getRect(_largeTitle).left, AppSpacing.screenGutter);
    expect(
      tester.getRect(find.text('9 月 19 日（週六）')).left,
      AppSpacing.screenGutter,
    );
    await disposeTree(tester);
  });

  testWidgets('Log has no compact bar: only the view switch stays', (
    tester,
  ) async {
    await _pumpApp(tester, tab: HomeTab.log);

    await _scroll(tester, 500);
    final pinnedTop = tester.getRect(find.text('時間軸').hitTestable()).top;
    expect(
      pinnedTop,
      lessThan(phoneTopInset + _toolbarHeight),
      reason: 'no toolbar row above the pinned switch',
    );

    await _scroll(tester, -120);
    expect(
      tester.getRect(find.text('時間軸').hitTestable()).top,
      pinnedTop,
      reason: 'scrolling up does not bring a small bar back',
    );
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('autoHide tucks the compact bar away while reading', (
    tester,
  ) async {
    Widget page({required bool isMinimized}) => ChromeVisibility(
      isMinimized: isMinimized,
      child: CollapsingPage(
        title: '測試',
        compactBar: CompactBarBehavior.autoHide,
        children: [for (var i = 0; i < 30; i++) SizedBox(height: 60)],
      ),
    );
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, page(isMinimized: false), store: store);
    await _scroll(tester, 400);
    final header = find.byType(ScrollEdgeGlass);
    expect(tester.getRect(header).height, phoneTopInset + _toolbarHeight);

    await pumpScreen(tester, page(isMinimized: true), store: store);
    await tester.pump(_settle);
    expect(tester.getRect(header).height, phoneTopInset);
    await disposeTree(tester);
  });

  testWidgets('the leading control moves clear of the window controls', (
    tester,
  ) async {
    const control = Key('leading');
    Widget page({required double windowControls}) => WindowControls(
      leadingInset: windowControls,
      child: const CollapsingPage(
        title: '測試',
        leading: SizedBox(key: control, width: 44, height: 44),
        children: [SizedBox(height: 60)],
      ),
    );
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, page(windowControls: 0), store: store);
    expect(tester.getTopLeft(find.byKey(control)).dx, AppSpacing.screenGutter);
    final titleLeft = tester.getTopLeft(find.text('測試').last).dx;

    await pumpScreen(tester, page(windowControls: 60), store: store);
    expect(
      tester.getTopLeft(find.byKey(control)).dx,
      AppSpacing.screenGutter + 60,
    );
    expect(
      tester.getTopLeft(find.text('測試').last).dx,
      titleLeft,
      reason: 'the large title sits below the controls and stays put',
    );
    await disposeTree(tester);
  });

  testWidgets('a bar over a picture stays clear until the page runs under '
      'it', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => CollapsingScrollView(
              header: CollapsingHeaderDelegate(
                toolbar: ToolbarMetrics.of(context),
                topInset: MediaQuery.paddingOf(context).top,
                largeHeight: 280,
                isClearUntilOverlap: true,
                large: const SizedBox.shrink(),
                compactTitle: const SizedBox.shrink(),
                leading: const AppBarBackButton(),
              ),
              children: [
                for (var i = 0; i < 30; i++)
                  const SizedBox(height: 80, child: Text('列')),
              ],
            ),
          ),
        ),
      ),
    );
    // The back button is glass of its own; the bar's is on top of that.
    int filters() => find.byType(BackdropFilter).evaluate().length;
    final buttons = filters();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -140));
    await tester.pump();
    expect(filters(), buttons, reason: 'half collapsed, still clear');

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump();
    expect(filters(), buttons + 1, reason: 'the page is under the bar');
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

    expect(_headerGlass, findsNothing);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  for (final tab in HomeTab.values) {
    testWidgets('a zero-width first frame does not break ${tab.name}', (
      tester,
    ) async {
      // Launching with the screen off lays the first frame out at zero size.
      tester.view
        ..physicalSize = Size.zero
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = AppStore(clock: FakeClock().now, isOnboarded: true)
        ..selectTab(tab);
      await tester.pumpWidget(MishirubeApp(store: store));

      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });
  }

  testWidgets('the food search stays pinned while the list scrolls', (
    tester,
  ) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    for (var i = 0; i < 30; i++) {
      store.backend.nutrition.saveFood(
        FoodItem(id: 'food$i', name: '食物 $i', kcal: 100),
      );
    }
    await pumpScreen(tester, const FoodSearchScreen(), store: store);
    final before = tester.getRect(find.byType(SearchField));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
    await tester.pumpAndSettle();

    final after = tester.getRect(find.byType(SearchField));
    expect(after.top, greaterThanOrEqualTo(phoneTopInset));
    expect(
      after.top,
      lessThan(before.top),
      reason:
          'it rides up with the title and then holds, like the log\'s '
          'view switch, instead of scrolling away with the list',
    );
    expect(find.byType(SearchField).hitTestable(), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('the filter button is as tall as the field is drawn', (
    tester,
  ) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    const frame = Key('frame');
    await pumpScreen(
      tester,
      const RepaintBoundary(
        key: frame,
        child: ExercisePickerScreen(purpose: PickerPurpose.browse),
      ),
      store: store,
    );

    // Layout boxes agreed before while the field's fill was drawn 8 pt
    // shorter than its box, so compare what is painted.
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(frame),
    );
    final image = (await tester.runAsync(() => boundary.toImage()))!;
    final pixels = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    final fill = AppColors.surface;
    bool isFill(int x, int y) {
      final i = (y * image.width + x) * 4;
      return (pixels.getUint8(i) - (fill.r * 255).round()).abs() < 3 &&
          (pixels.getUint8(i + 1) - (fill.g * 255).round()).abs() < 3 &&
          (pixels.getUint8(i + 2) - (fill.b * 255).round()).abs() < 3;
    }

    int paintedHeight(Rect box, double x) => [
      for (var y = box.top.round(); y < box.bottom.round(); y++)
        if (isFill(x.round(), y)) y,
    ].length;

    final field = tester.getRect(find.byType(SearchField));
    final button = tester.getRect(find.byType(SearchFieldButton));
    // Sample clear of the rounded corners, the hint text and the icon.
    expect(
      paintedHeight(field, field.right - 30),
      paintedHeight(button, button.left + 14),
      reason: 'the grey of the field and of the button are one height',
    );
    await disposeTree(tester);
  });
}
