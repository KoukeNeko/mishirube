import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/features/journal/weight_entry_screen.dart';
import 'package:mishirube/features/log/log_screen.dart';
import 'package:mishirube/features/training/active_workout_screen.dart';
import 'package:mishirube/features/nutrition/nutrition_view_model.dart';
import 'package:mishirube/features/shell/bottom_chrome/chrome_metrics.dart';
import 'package:mishirube/features/shell/bottom_chrome/press_feedback.dart';
import 'package:mishirube/features/record/record_options.dart';
import 'package:mishirube/features/shell/bottom_chrome/quick_log_menu.dart';
import 'package:mishirube/features/shell/bottom_chrome/session_accessory.dart';
import 'package:mishirube/features/shell/bottom_chrome/split_dock.dart';
import 'package:mishirube/features/today/today_screen.dart';
import 'package:mishirube/shared/widgets/widgets.dart';
import 'package:mishirube/l10n/l10n.dart';

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

  testWidgets('only the tab on screen keeps its tickers running', (
    tester,
  ) async {
    await _pumpApp(tester, FakeClock());
    bool ticks(Type tab) => TickerMode.valuesOf(
      tester.element(find.byType(tab, skipOffstage: false)),
    ).enabled;

    expect(ticks(TodayScreen), isTrue);
    expect(ticks(LogScreen), isFalse);

    await tester.tap(find.bySemanticsLabel('紀錄'));
    await _settleFor(tester);

    expect(ticks(TodayScreen), isFalse);
    expect(ticks(LogScreen), isTrue);
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

  testWidgets('dock tabs and 「+」 show no Material ink', (tester) async {
    final store = await _pumpApp(tester, FakeClock());

    for (final target in [
      find.bySemanticsLabel('紀錄'),
      find.byKey(_centerAction),
    ]) {
      expect(
        find.descendant(of: target, matching: find.byType(InkResponse)),
        findsNothing,
      );
    }

    await tester.tap(find.bySemanticsLabel('紀錄'));
    await _settleFor(tester);
    expect(store.selectedTab, HomeTab.log);
    await disposeTree(tester);
  });

  testWidgets('「+」opens the quick-log menu and × closes it', (tester) async {
    await _pumpApp(tester, FakeClock());

    await tester.tap(find.byKey(_centerAction));
    await _settleFor(tester);
    expect(
      find.descendant(
        of: find.byKey(quickLogMenuKey),
        matching: find.text('訓練'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('關閉'));
    await _settleFor(tester);
    expect(find.byKey(quickLogMenuKey), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('a category stays in one row, and what is done through the day '
      'is the row nearest the thumb', (tester) async {
    await _pumpApp(tester, FakeClock());

    await tester.tap(find.byKey(_centerAction));
    await _settleFor(tester);
    final menu = find.byKey(quickLogMenuKey);
    Finder labelled(String label) =>
        find.descendant(of: menu, matching: find.text(label));
    Rect tile(String label) => tester.getRect(
      find.ancestor(of: labelled(label), matching: find.byType(InkWell)),
    );

    const done = ['訓練', '運動', '飲食', '水'];
    const body = ['體重', '圍度', '身體組成'];
    const states = ['睡眠', '洗澡', '心情、精力、症狀'];
    for (final row in [done, body, states]) {
      expect(
        {for (final label in row) tile(label).top.round()},
        hasLength(1),
        reason: '$row stand in one row',
      );
      expect(
        {for (final label in row) tile(label).width.round()},
        hasLength(1),
        reason: '$row are of one width',
      );
      final lefts = [for (final label in row) tile(label).left];
      expect(lefts, [...lefts]..sort(), reason: '$row keep the list order');
    }

    expect(tile('睡眠').bottom, lessThan(tile('體重').top));
    expect(tile('體重').bottom, lessThan(tile('訓練').top));
    expect(
      tile('體重').top - tile('睡眠').bottom,
      moreOrLessEquals(AppSpacing.xs, epsilon: 0.5),
      reason: 'rows of one kind are a tile gap apart',
    );
    expect(
      tile('訓練').top - tile('體重').bottom,
      moreOrLessEquals(AppSpacing.sm, epsilon: 0.5),
      reason: 'the larger row stands a little apart',
    );
    expect(
      tile('訓練').height,
      greaterThan(tile('體重').height),
      reason: 'what is done through the day has the larger tiles',
    );

    final panel = tester.getRect(find.byKey(quickLogPanelKey));
    final dock = tester.getRect(find.byType(SplitDock));
    expect(panel.left, moreOrLessEquals(dock.left, epsilon: 0.5));
    expect(panel.right, moreOrLessEquals(dock.right, epsilon: 0.5));
    expect(
      tester.getRect(find.byTooltip('關閉')).top - panel.bottom,
      moreOrLessEquals(10, epsilon: 0.5),
      reason: '× sits under the panel where「+」was',
    );
    await disposeTree(tester);
  });

  testWidgets('a label a character too long shrinks instead of leaving that '
      'character alone on a second line', (tester) async {
    await _pumpApp(tester, FakeClock());

    await tester.tap(find.byKey(_centerAction));
    await _settleFor(tester);
    final label = find.descendant(
      of: find.byKey(quickLogMenuKey),
      matching: find.text('心情、精力、症狀'),
    );
    expect(tester.getSize(label).height, lessThan(20), reason: 'one line');
    await disposeTree(tester);
  });

  testWidgets('the panel grows out of the「+」and ends above it', (tester) async {
    await _pumpApp(tester, FakeClock());
    final plus = tester.getRect(find.byKey(_centerAction));
    Rect glass() => tester.getRect(find.byKey(quickLogPanelKey));

    await tester.tap(find.byKey(_centerAction));
    await tester.pump();
    final first = glass();
    expect(
      plus.contains(first.center),
      isTrue,
      reason: 'it starts inside the button, behind it',
    );
    expect(first.shortestSide, lessThan(plus.shortestSide / 4));

    await tester.pump(const Duration(milliseconds: 60));
    final midway = glass();
    expect(midway.width, greaterThan(first.width));
    expect(midway.top, lessThan(first.top), reason: 'it rises as it grows');

    await _settleFor(tester);
    final last = glass();
    expect(last.width, greaterThan(300));
    expect(last.bottom, lessThan(plus.top), reason: 'it ends above the button');
    await disposeTree(tester);
  });

  testWidgets('the panel folds back into「+」on close', (tester) async {
    await _pumpApp(tester, FakeClock());

    await tester.tap(find.byKey(_centerAction));
    await _settleFor(tester);
    await tester.tap(find.byTooltip('關閉'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      find.byKey(quickLogMenuKey),
      findsOneWidget,
      reason: 'closing plays the arrival backwards instead of cutting',
    );
    await _settleFor(tester);
    expect(find.byKey(quickLogMenuKey), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('the menu offers every enabled module and nothing else', (
    tester,
  ) async {
    final store = await _pumpApp(tester, FakeClock());
    final l10n = lookupAppLocalizations(testLocale);
    List<String> shown() => [
      for (final option in recordOptions)
        if (find
            .descendant(
              of: find.byKey(quickLogMenuKey),
              matching: find.text(option.title(l10n)),
            )
            .evaluate()
            .isNotEmpty)
          option.title(l10n),
    ];

    await tester.tap(find.byKey(_centerAction));
    await _settleFor(tester);
    expect(shown(), [
      for (final option in recordOptions)
        if (store.enabledModules.contains(option.module)) option.title(l10n),
    ], reason: 'all of them, not the first few and a「更多」');
    expect(find.text('更多紀錄類型'), findsNothing);
    await tester.tap(find.byTooltip('關閉'));
    await _settleFor(tester);

    store.toggleModule(AppModule.notes);
    await tester.pump();
    await tester.tap(find.byKey(_centerAction));
    await _settleFor(tester);
    expect(
      find.descendant(
        of: find.byKey(quickLogMenuKey),
        matching: find.text('筆記'),
      ),
      store.enabledModules.contains(AppModule.notes)
          ? findsOneWidget
          : findsNothing,
      reason: 'switching a module changes the menu with it',
    );
    await disposeTree(tester);
  });

  testWidgets('water, which writes at once, says how much and sits beside '
      'the meal rather than in it', (tester) async {
    final store = await _pumpApp(tester, FakeClock());
    final nutrition = NutritionViewModel(store.backend);
    addTearDown(nutrition.dispose);
    final menu = find.byKey(quickLogMenuKey);
    Finder inMenu(Finder finder) => find.descendant(of: menu, matching: finder);

    await tester.tap(find.byKey(_centerAction));
    await _settleFor(tester);
    expect(
      inMenu(find.textContaining(' mL')),
      findsOneWidget,
      reason: 'only the option that writes at once says what it writes',
    );
    expect(
      inMenu(find.text('${nutrition.glassMillilitres} mL')),
      findsOneWidget,
    );
    Rect tile(String label) => tester.getRect(
      find.ancestor(
        of: inMenu(find.text(label)),
        matching: find.byType(InkWell),
      ),
    );
    expect(
      tile('水').left,
      moreOrLessEquals(tile('飲食').right + AppSpacing.xs, epsilon: 0.5),
      reason: 'water is a module of its own, a tile of its own',
    );
    expect(tile('水').top, tile('飲食').top);

    await tester.tap(find.byTooltip('關閉'));
    await _settleFor(tester);
    nutrition.setGlassMillilitres(330);
    await tester.tap(find.byKey(_centerAction));
    await _settleFor(tester);
    expect(
      inMenu(find.text('330 mL')),
      findsOneWidget,
      reason: 'the glass the user chose',
    );
    await disposeTree(tester);
  });

  testWidgets('water from the menu is one tap, and can be taken back', (
    tester,
  ) async {
    final store = await _pumpApp(tester, FakeClock());
    final before = store.todayMeals.length;

    await tester.tap(find.byKey(_centerAction));
    await _settleFor(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(quickLogMenuKey),
        matching: find.text('水'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      find.text('復原'),
      findsNothing,
      reason: 'the toast does not land on the menu while it folds away',
    );
    await _settleFor(tester);

    expect(store.todayMeals, hasLength(before + 1));
    final nutrition = NutritionViewModel(store.backend);
    addTearDown(nutrition.dispose);
    expect(store.todayMeals.last.millilitres, nutrition.glassMillilitres);
    expect(find.byKey(quickLogMenuKey), findsNothing, reason: 'nothing opens');

    // The toast waits for the menu to finish closing, then comes in.
    await _settleFor(tester);
    await tester.tap(find.text('復原'));
    await tester.pump();
    expect(store.todayMeals, hasLength(before));
    await disposeTree(tester);
  });

  testWidgets('a small screen with large text scrolls the menu', (
    tester,
  ) async {
    usePhoneViewport(tester);
    // iPhone SE size, the largest standard text setting.
    tester.view.physicalSize = const Size(375, 667);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await tester.pumpWidget(MishirubeApp(store: store));
    await tester.pump();

    await tester.tap(find.byKey(_centerAction));
    await _settleFor(tester);
    expect(
      tester.takeException(),
      isNull,
      reason: 'every type is offered, so they must fit or scroll',
    );
    expect(find.byTooltip('關閉'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('the dock labels keep their size with large text', (
    tester,
  ) async {
    usePhoneViewport(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await tester.pumpWidget(MishirubeApp(store: store));
    await tester.pump();

    final label = find.descendant(
      of: find.byType(SplitDock),
      matching: find.text('紀錄'),
    );
    expect(
      MediaQuery.textScalerOf(tester.element(label)).scale(10),
      10,
      reason: 'the dock is a fixed height; a larger label is cut off',
    );
    await disposeTree(tester);
  });

  testWidgets('workout accessory ticks, pauses and resumes', (tester) async {
    final clock = FakeClock();
    final store = await _pumpApp(tester, clock);
    store
      ..startWorkout()
      ..beginWorkout()
      ..beginWorkout();
    await _settleFor(tester);

    // The state and the clock are separate: the clock stays put while the
    // label gives way, so they are checked as a pair.
    void expectAccessory(String state, String elapsed) {
      final bar = find.byType(SessionAccessory);
      expect(
        find.descendant(of: bar, matching: find.textContaining(state)),
        findsOneWidget,
        reason: state,
      );
      expect(
        find.descendant(of: bar, matching: find.text(elapsed)),
        findsOneWidget,
        reason: elapsed,
      );
    }

    expectAccessory('訓練進行中', '0:00');

    clock.advance(const Duration(seconds: 65));
    await tester.pump(const Duration(seconds: 1));
    expectAccessory('訓練進行中', '1:05');

    await tester.tap(find.byTooltip('暫停訓練'));
    clock.advance(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 1));
    expectAccessory('已暫停', '1:05');

    await tester.tap(find.byTooltip('繼續訓練'));
    clock.advance(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    expectAccessory('訓練進行中', '1:15');
    await disposeTree(tester);
  });

  testWidgets('a scheduled workout is only a way back, with no pause or end', (
    tester,
  ) async {
    final store = await _pumpApp(tester, FakeClock());
    store.startWorkout();
    await _settleFor(tester);

    final bar = find.byType(SessionAccessory);
    expect(
      find.descendant(of: bar, matching: find.textContaining('已安排')),
      findsOneWidget,
    );
    expect(find.byTooltip('暫停訓練'), findsNothing);
    expect(find.byTooltip('繼續訓練'), findsNothing);
    expect(find.byTooltip('結束訓練'), findsNothing);
    expect(
      find.descendant(of: bar, matching: find.text('0:00')),
      findsNothing,
      reason: 'no time runs yet',
    );

    // Minimised, the centre stays the「+」: there is no timer to show.
    store.selectTab(HomeTab.log);
    await _settleFor(tester);
    await tester.drag(_visibleScrollView, const Offset(0, -300));
    await _settleFor(tester);
    expect(find.byIcon(Icons.add), findsWidgets);
    expect(find.text('0:00'), findsNothing);
    await tester.drag(_visibleScrollView, const Offset(0, 200));
    await _settleFor(tester);

    await tester.tap(find.byKey(const ValueKey('session-accessory-open')));
    await _settleFor(tester);
    expect(find.byType(ActiveWorkoutScreen), findsOneWidget);
    expect(
      store.activeWorkout!.isReady,
      isTrue,
      reason: 'opening is not beginning',
    );

    Navigator.of(tester.element(find.byType(ActiveWorkoutScreen))).pop();
    store.beginWorkout();
    await _settleFor(tester);
    expect(find.byTooltip('暫停訓練'), findsOneWidget);
    expect(find.byTooltip('結束訓練'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('scrolling down folds the accessory into a centre timer', (
    tester,
  ) async {
    final store = await _pumpApp(tester, FakeClock());
    store
      ..startWorkout()
      ..beginWorkout()
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

  testWidgets('minimising with nothing running keeps the「+」', (tester) async {
    final store = await _pumpApp(tester, FakeClock());
    store.selectTab(HomeTab.log);
    await _settleFor(tester);

    await tester.drag(_visibleScrollView, const Offset(0, -300));
    await _settleFor(tester);

    final plus = tester.widget<Opacity>(
      find
          .descendant(
            of: find.byKey(_centerAction),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(plus.opacity, 1, reason: 'there is no timer to hand over to');
    expect(find.byIcon(Icons.add), findsWidgets);
    await disposeTree(tester);
  });

  testWidgets('the running label comes back with the bar, not a tick later', (
    tester,
  ) async {
    final clock = FakeClock();
    final store = await _pumpApp(tester, clock);
    store
      ..startWorkout()
      ..beginWorkout()
      ..selectTab(HomeTab.log);
    await _settleFor(tester);

    await tester.drag(_visibleScrollView, const Offset(0, -300));
    await _settleFor(tester);
    await tester.drag(_visibleScrollView, const Offset(0, 200));
    await _settleFor(tester);

    // No clock tick in between: the label is driven by the animation,
    // not by the second hand.
    expect(
      find.descendant(
        of: find.byType(SessionAccessory),
        matching: find.textContaining('訓練進行中'),
      ),
      findsOneWidget,
    );
    await disposeTree(tester);
  });

  testWidgets('the accessory is squeezed into the timer, not cut away', (
    tester,
  ) async {
    final store = await _pumpApp(tester, FakeClock());
    store
      ..startWorkout()
      ..beginWorkout()
      ..selectTab(HomeTab.log);
    await _settleFor(tester);

    final accessory = find.byType(SessionAccessory);
    final centre = find.byKey(const ValueKey('dock-center-action'));
    final wide = tester.getSize(accessory).width;
    final plus = tester.getSize(centre).width;

    await tester.drag(_visibleScrollView, const Offset(0, -300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final narrowing = tester.getSize(accessory).width;
    final growing = tester.getSize(centre).width;
    expect(
      narrowing,
      lessThan(wide),
      reason: 'the bar is on its way into the capsule, not switched off',
    );
    expect(narrowing, greaterThan(ChromeMetrics.timerCapsuleWidth));
    expect(growing, greaterThan(plus), reason: 'the capsule grows to meet it');
    expect(growing, lessThan(ChromeMetrics.timerCapsuleWidth));

    await _settleFor(tester);
    expect(accessory, findsNothing);
    expect(tester.getSize(centre).width, ChromeMetrics.timerCapsuleWidth);
    await disposeTree(tester);
  });

  testWidgets('stop asks for confirmation, then shows the summary', (
    tester,
  ) async {
    final store = await _pumpApp(tester, FakeClock());
    store
      ..startWorkout()
      ..beginWorkout()
      ..beginWorkout();
    await _settleFor(tester);

    await tester.tap(find.byTooltip('結束訓練'));
    await _settleFor(tester);
    expect(find.text('結束這次訓練？'), findsOneWidget);

    await tester.tap(find.text('結束並儲存'));
    await _settleFor(tester);
    expect(store.activeWorkout, isNull);
    expect(find.text('這次的負荷'), findsOneWidget, reason: 'the summary');
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
    final store = AppStore(clock: clock.now, isOnboarded: true)
      ..startWorkout()
      ..beginWorkout();

    clock.advance(const Duration(minutes: 10));
    store.togglePause();
    clock.advance(const Duration(minutes: 3));
    store.togglePause();
    clock.advance(const Duration(minutes: 2));
    store.finishWorkout();

    final workout = store.lastFinishedWorkout!;
    expect(workout.elapsedAt(clock.now()), const Duration(minutes: 12));
  });

  group('dock press feedback', () {
    Finder dockLabel(String label) =>
        find.descendant(of: find.byType(SplitDock), matching: find.text(label));

    double tabScale(WidgetTester tester) => tester
        .widget<ScaleTransition>(
          find
              .descendant(
                of: find.ancestor(
                  of: dockLabel('紀錄'),
                  matching: find.byType(PressScale),
                ),
                matching: find.byType(ScaleTransition),
              )
              .first,
        )
        .scale
        .value;

    testWidgets('a tab squeezes while held and springs back', (tester) async {
      await _pumpApp(tester, FakeClock());

      final gesture = await tester.startGesture(
        tester.getCenter(dockLabel('紀錄')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tabScale(tester), ChromeMetrics.tabPressedScale);

      await gesture.up();
      await tester.pump();
      await tester.pump(_settle);
      expect(tabScale(tester), closeTo(1, 0.001));
      await disposeTree(tester);
    });

    testWidgets('Reduce Motion keeps a held tab still', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _pumpApp(tester, FakeClock());

      final gesture = await tester.startGesture(
        tester.getCenter(dockLabel('紀錄')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tabScale(tester), 1);
      await gesture.up();
      await disposeTree(tester);
    });

    testWidgets('the lens follows selection within its capsule', (
      tester,
    ) async {
      await _pumpApp(tester, FakeClock());
      final lens = find.byKey(const ValueKey('dock-selection-lens')).first;

      expect(
        tester.getCenter(lens).dx,
        closeTo(tester.getCenter(dockLabel('今天')).dx, 0.5),
      );
      await tester.tap(find.bySemanticsLabel('紀錄'));
      await _settleFor(tester);
      expect(
        tester.getCenter(lens).dx,
        closeTo(tester.getCenter(dockLabel('紀錄')).dx, 0.5),
      );

      // Concentric with its capsule at any dock height.
      final capsule = tester.getRect(
        find.ancestor(of: lens, matching: find.byType(ChromeSurface)).first,
      );
      final lensRect = tester.getRect(lens);
      expect(lensRect.top - capsule.top, ChromeMetrics.lensInset);
      expect(capsule.bottom - lensRect.bottom, ChromeMetrics.lensInset);
      await disposeTree(tester);
    });

    testWidgets(
      'iOS ticks only when the selection changes',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
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
        await _pumpApp(tester, FakeClock());

        final logTab = find.descendant(
          of: find.byType(SplitDock),
          matching: find.bySemanticsLabel('紀錄'),
        );
        await tester.tap(logTab);
        await _settleFor(tester);
        await tester.tap(logTab);
        await _settleFor(tester);
        expect(haptics, ['HapticFeedbackType.selectionClick']);

        await tester.tap(find.byKey(_centerAction));
        await _settleFor(tester);
        expect(haptics.last, 'HapticFeedbackType.lightImpact');
        await disposeTree(tester);
      },
    );
  });

  group('dock hold-to-drag', () {
    Finder dockLabel(String label) =>
        find.descendant(of: find.byType(SplitDock), matching: find.text(label));
    final lens = find.byKey(const ValueKey('dock-selection-lens')).first;

    Future<TestGesture> holdOn(WidgetTester tester, String label) async {
      final gesture = await tester.startGesture(
        tester.getCenter(dockLabel(label)),
      );
      await tester.pump(ChromeMetrics.scrubHoldDuration);
      await tester.pump(const Duration(milliseconds: 50));
      return gesture;
    }

    testWidgets(
      'holding and dragging selects the tab under the finger on release',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
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
        final store = await _pumpApp(tester, FakeClock());
        final target = tester.getCenter(dockLabel('紀錄'));

        final gesture = await holdOn(tester, '今天');
        await gesture.moveTo(target);
        await tester.pump();
        expect(store.selectedTab, HomeTab.today, reason: 'only a preview');
        expect(tester.getCenter(lens).dx, closeTo(target.dx, 0.5));
        expect(haptics, ['HapticFeedbackType.selectionClick']);

        await gesture.up();
        await _settleFor(tester);
        expect(store.selectedTab, HomeTab.log);
        expect(haptics, hasLength(1), reason: 'no extra tick on release');
        await disposeTree(tester);
      },
    );

    testWidgets('releasing over「+」cancels without opening the menu', (
      tester,
    ) async {
      final store = await _pumpApp(tester, FakeClock());

      final gesture = await holdOn(tester, '今天');
      await gesture.moveTo(tester.getCenter(dockLabel('紀錄')));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.byKey(_centerAction)));
      await tester.pump();
      await gesture.up();
      await _settleFor(tester);

      expect(store.selectedTab, HomeTab.today);
      expect(find.byKey(quickLogMenuKey), findsNothing);
      expect(
        tester.getCenter(lens).dx,
        closeTo(tester.getCenter(dockLabel('今天')).dx, 0.5),
        reason: 'the lens springs back to the selected tab',
      );
      await disposeTree(tester);
    });

    testWidgets('a quick tap still selects without dragging', (tester) async {
      final store = await _pumpApp(tester, FakeClock());
      await tester.tap(dockLabel('趨勢'));
      await _settleFor(tester);
      expect(store.selectedTab, HomeTab.trends);
      await disposeTree(tester);
    });
  });

  group('quick-log menu pushes the app back', () {
    Rect contentRect(WidgetTester tester) => tester.getRect(
      find
          .descendant(
            of: find.byType(QuickLogRecess),
            matching: find.byType(IndexedStack),
          )
          .first,
    );

    testWidgets(
      'iOS shrinks page content but not the dock',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
        await _pumpApp(tester, FakeClock());
        final dockBefore = tester.getRect(find.byType(SplitDock));

        await tester.tap(find.byKey(_centerAction));
        await _settleFor(tester);

        expect(
          contentRect(tester).width,
          closeTo(phoneSize.width * 0.975, 0.01),
        );
        expect(
          tester.getRect(find.byType(SplitDock)),
          dockBefore,
          reason: 'the dock keeps its size',
        );
        expect(
          tester.getRect(find.byType(Scaffold).first).width,
          phoneSize.width,
          reason: 'the page background still fills the screen',
        );
        expect(
          find.ancestor(
            of: find.byType(IndexedStack),
            matching: find.byType(ImageFiltered),
          ),
          findsNothing,
          reason: 'the app behind the menu is dimmed, not blurred',
        );
        double centerOpacity() => tester
            .widget<Opacity>(
              find.byKey(const ValueKey('dock-center-visibility')),
            )
            .opacity;
        expect(centerOpacity(), 0, reason: '× stands in for the「+」');

        await tester.tap(find.byTooltip('關閉'));
        await _settleFor(tester);
        expect(contentRect(tester).width, phoneSize.width);
        expect(centerOpacity(), 1);
        await disposeTree(tester);
      },
    );

    testWidgets('Android only dims', (tester) async {
      await _pumpApp(tester, FakeClock());
      await tester.tap(find.byKey(_centerAction));
      await _settleFor(tester);
      expect(contentRect(tester).width, phoneSize.width);
      await disposeTree(tester);
    });

    testWidgets(
      'iOS Reduce Motion keeps the app full size',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await _pumpApp(tester, FakeClock());
        await tester.tap(find.byKey(_centerAction));
        await _settleFor(tester);
        expect(contentRect(tester).width, phoneSize.width);
        await disposeTree(tester);
      },
    );
  });

  testWidgets('sliding sideways drags without holding first', (tester) async {
    final store = await _pumpApp(tester, FakeClock());
    Finder dockLabel(String label) =>
        find.descendant(of: find.byType(SplitDock), matching: find.text(label));

    final gesture = await tester.startGesture(
      tester.getCenter(dockLabel('今天')),
    );
    final target = tester.getCenter(dockLabel('紀錄'));
    for (var i = 1; i <= 5; i++) {
      await gesture.moveTo(
        Offset.lerp(tester.getCenter(dockLabel('今天')), target, i / 5)!,
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(store.selectedTab, HomeTab.today);
    await gesture.up();
    await _settleFor(tester);
    expect(store.selectedTab, HomeTab.log);
    await disposeTree(tester);
  });

  testWidgets('releasing above the dock still selects the tab below', (
    tester,
  ) async {
    final store = await _pumpApp(tester, FakeClock());
    Finder dockLabel(String label) =>
        find.descendant(of: find.byType(SplitDock), matching: find.text(label));

    final start = tester.getCenter(dockLabel('今天'));
    final gesture = await tester.startGesture(start);
    final target = tester.getCenter(dockLabel('紀錄')) - const Offset(0, 120);
    for (var i = 1; i <= 5; i++) {
      await gesture.moveTo(Offset.lerp(start, target, i / 5)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await _settleFor(tester);
    expect(store.selectedTab, HomeTab.log);
    await disposeTree(tester);
  });

  testWidgets(
    '「+」is painted after the capsules so their glass cannot blur it',
    (tester) async {
      await _pumpApp(tester, FakeClock());
      // Later in tree order paints later; a capsule's backdrop blur only
      // samples what was painted before it.
      final order = find
          .descendant(
            of: find.byType(SplitDock),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is ChromeSurface || widget.key == _centerAction,
            ),
          )
          .evaluate()
          .map((element) => element.widget is ChromeSurface ? 'glass' : '+')
          .toList();
      // Both capsules, then「+」on its own glass.
      expect(order, ['glass', 'glass', 'glass', '+']);

      final dock = tester.getRect(find.byType(SplitDock));
      expect(
        tester.getCenter(find.byKey(_centerAction)).dx,
        closeTo(dock.center.dx, 0.01),
      );
      await disposeTree(tester);
    },
  );

  testWidgets(
    'buttons tap, choices tick, back stays silent',
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    (tester) async {
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
      final store = await _pumpApp(tester, FakeClock());
      store.selectTab(HomeTab.log);
      await _settleFor(tester);

      await tester.tap(find.text('飲食').hitTestable().first);
      await tester.pump();
      expect(haptics, ['HapticFeedbackType.selectionClick']);

      await tester.tap(find.text('今天').hitTestable().first);
      await tester.pump();
      expect(haptics.last, 'HapticFeedbackType.lightImpact');

      haptics.clear();
      await disposeTree(tester);
      await pumpScreen(
        tester,
        const WeightEntryScreen(),
        store: AppStore(clock: FakeClock().now, isOnboarded: true),
      );
      await tester.tap(find.byType(AppBarBackButton));
      await tester.pump();
      expect(haptics, isEmpty);
      await disposeTree(tester);
    },
  );

  testWidgets('× is the same glyph size as the「+」it replaces', (tester) async {
    await _pumpApp(tester, FakeClock());
    await tester.tap(find.byKey(_centerAction));
    await _settleFor(tester);

    // Only the dock's「+」and the menu's ×: the page behind may show「+」
    // buttons of its own.
    final plus = find.descendant(
      of: find.byKey(_centerAction),
      matching: find.byIcon(Icons.add),
    );
    final cross = find.descendant(
      of: find.byKey(quickLogMenuKey),
      matching: find.byIcon(Icons.add),
    );
    expect(plus, findsOneWidget);
    expect(cross, findsOneWidget, reason: '× is the「+」turned');
    expect(tester.widget<Icon>(cross).size, tester.widget<Icon>(plus).size);
    await disposeTree(tester);
  });
}
