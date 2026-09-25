import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/features/trends/trends_screen.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/features/exercise/exercise_picker_screen.dart';
import 'package:mishirube/features/journal/weight_entry_screen.dart';
import 'package:mishirube/features/me/export_screen.dart';
import 'package:mishirube/features/me/me_screen.dart';
import 'package:mishirube/features/me/privacy_screen.dart';
import 'package:mishirube/features/nutrition/food_search_screen.dart';
import 'package:mishirube/features/shell/bottom_chrome/app_bottom_chrome.dart';
import 'package:mishirube/features/shell/bottom_chrome/chrome_metrics.dart';
import 'package:mishirube/features/shell/bottom_chrome/quick_log_menu.dart';
import 'package:mishirube/features/shell/bottom_chrome/split_dock.dart';
import 'package:mishirube/features/shell/home_shell.dart';
import 'package:mishirube/features/today/today_screen.dart';
import 'package:mishirube/features/training/active_workout_screen.dart';
import 'package:mishirube/features/training/workout_summary_screen.dart';
import 'package:mishirube/shared/widgets/widgets.dart';
import 'package:mishirube/shared/window_layout.dart';

import 'support/harness.dart';

/// Every breakpoint from both sides, and the sizes Android's adaptive
/// guidance tests against.
const _matrix = [
  phone,
  phoneLandscape,
  WindowCase('599 × 900', Size(599, 900)),
  WindowCase('600 × 900', Size(600, 900)),
  WindowCase('839 × 900', Size(839, 900)),
  WindowCase('840 × 900', Size(840, 900)),
  WindowCase('1199 × 900', Size(1199, 900)),
  WindowCase('1200 × 900', Size(1200, 900)),
  WindowCase('1599 × 900', Size(1599, 900)),
  WindowCase('1600 × 900, a Chromebook', Size(1600, 900)),
  WindowCase('foldable', Size(841, 701)),
  WindowCase('8" tablet', Size(1024, 640)),
  tablet,
];

/// A foldable opened like a book and bent at the fold.
const _bookPosture = WindowCase(
  'book posture',
  Size(841, 701),
  displayFeatures: [
    DisplayFeature(
      bounds: Rect.fromLTWH(420, 0, 0, 701),
      type: DisplayFeatureType.fold,
      state: DisplayFeatureState.postureHalfOpened,
    ),
  ],
);

/// The same foldable opened flat: the fold is a crease, not a divide.
const _flatFold = WindowCase(
  'flat fold',
  Size(841, 701),
  displayFeatures: [
    DisplayFeature(
      bounds: Rect.fromLTWH(420, 0, 0, 701),
      type: DisplayFeatureType.fold,
      state: DisplayFeatureState.postureFlat,
    ),
  ],
);

/// Two screens and a hinge between them, which hides whatever is under it.
const _dualScreen = WindowCase(
  'dual screen',
  Size(1114, 720),
  displayFeatures: [
    DisplayFeature(
      bounds: Rect.fromLTWH(540, 0, 34, 720),
      type: DisplayFeatureType.hinge,
      state: DisplayFeatureState.postureFlat,
    ),
  ],
);

/// The inner screen of a Galaxy Z Fold, narrower than two panes need.
WindowCase _galaxyFold(DisplayFeatureState posture) => WindowCase(
  'Galaxy Z Fold, $posture',
  const Size(690, 829),
  displayFeatures: [
    DisplayFeature(
      bounds: const Rect.fromLTWH(345, 0, 0, 829),
      type: DisplayFeatureType.fold,
      state: posture,
    ),
  ],
);

AppStore _store() => AppStore(clock: FakeClock().now, isOnboarded: true);

Iterable<Rect> _cardRects(WidgetTester tester) => [
  for (final type in [AppCard, GroupedCard])
    for (final element in find.byType(type).evaluate())
      tester.getRect(find.byWidget(element.widget)),
];

/// Taps a row of 我的, scrolling to it first: rows below the fold are
/// not built until then.
Future<void> _tapRow(WidgetTester tester, String title) async {
  final row = find.descendant(
    of: find.byType(MeScreen),
    matching: find.text(title),
  );
  await tester.scrollUntilVisible(
    row,
    200,
    scrollable: find
        .descendant(
          of: find.byType(MeScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(row.hitTestable());
  await tester.pumpAndSettle();
}

void main() {
  group('every window size', () {
    for (final window in _matrix) {
      testWidgets('$window: the chrome fits and cards keep the gutter', (
        tester,
      ) async {
        final store = _store();
        await pumpScreen(
          tester,
          const HomeShell(),
          store: store,
          window: window,
        );
        // Where a phone has it: along the bottom of the page, which with
        // two panes is the main pane on the left.
        final pageLeft = window.padding.left;
        final pageRight = window.size.width >= expandedWidth
            ? mainPaneWidthFor(window.size.width)
            : window.size.width - window.padding.right;
        final dock = tester.getRect(find.byType(SplitDock));
        expect(dock.width, lessThanOrEqualTo(ChromeMetrics.dockMaxWidth));
        expect(
          dock.center.dx,
          moreOrLessEquals((pageLeft + pageRight) / 2, epsilon: 0.5),
          reason: 'the dock floats centred along the bottom of the page',
        );
        expect(dock.bottom, greaterThan(window.size.height - 60));

        for (final tab in HomeTab.values) {
          store.selectTab(tab);
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$tab');
          for (final card in _cardRects(tester)) {
            expect(
              card.left,
              greaterThanOrEqualTo(pageLeft + AppSpacing.screenGutter - 0.01),
              reason: '$tab: a card keeps the gutter from its page edge',
            );
            expect(
              card.right,
              lessThanOrEqualTo(pageRight - AppSpacing.screenGutter + 0.01),
              reason: '$tab: a card keeps the gutter from its page edge',
            );
            expect(card.left, greaterThanOrEqualTo(window.padding.left));
            expect(
              card.right,
              lessThanOrEqualTo(window.size.width - window.padding.right),
              reason: '$tab: nothing under the notch of a phone on its side',
            );
          }
        }
        await disposeTree(tester);
      });
    }
  });

  testWidgets('pages run under the floating dock, edge to edge', (
    tester,
  ) async {
    const wide = WindowCase('839 × 900', Size(839, 900));
    await pumpScreen(tester, const HomeShell(), store: _store(), window: wide);

    final page = tester.getRect(find.byType(CollapsingScrollView).first);
    expect(page.left, 0);
    expect(page.right, wide.size.width);
    expect(page.bottom, wide.size.height);
    await disposeTree(tester);
  });

  testWidgets('with two panes the dock and its menu keep to the main pane', (
    tester,
  ) async {
    final store = _store();
    await pumpScreen(tester, const HomeShell(), store: store, window: tablet);

    for (final tab in HomeTab.values) {
      store.selectTab(tab);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(SplitDock)).center.dx,
        moreOrLessEquals(mainPaneWidthFor(tablet.size.width) / 2, epsilon: 0.5),
        reason: '$tab: the dock stays put between tabs',
      );
    }

    const plusKey = ValueKey('dock-center-action');
    final plus = tester.getRect(find.byKey(plusKey));
    await tester.tap(find.byKey(plusKey));
    await tester.pumpAndSettle();
    final close = tester.getRect(
      find.descendant(
        of: find.byKey(quickLogMenuKey),
        matching: find.byTooltip('關閉'),
      ),
    );
    expect(close.center.dx, moreOrLessEquals(plus.center.dx, epsilon: 0.5));
    expect(close.center.dy, moreOrLessEquals(plus.center.dy, epsilon: 0.5));
    await disposeTree(tester);
  });

  testWidgets('a row of chips runs off the screen, its first chip in line '
      'with the cards', (tester) async {
    await pumpScreen(
      tester,
      const FoodSearchScreen(),
      store: _store(),
      window: tablet,
    );

    final row = find.ancestor(
      of: find.byType(SelectChip).first,
      matching: find.byType(ListView),
    );
    final rowRect = tester.getRect(row);
    expect(rowRect.left, 0);
    expect(rowRect.right, tablet.size.width);
    expect(
      tester.getRect(find.byType(SelectChip).first).left,
      AppSpacing.screenGutter,
    );
    await disposeTree(tester);
  });

  testWidgets('trends puts the long run beside the changes when there is '
      'room', (tester) async {
    for (final (window, isWide) in [
      (phone, false),
      (const WindowCase('839 × 900', Size(839, 900)), true),
    ]) {
      final store = _store()..selectTab(HomeTab.trends);
      await pumpScreen(tester, const HomeShell(), store: store, window: window);
      final changes = tester.getRect(
        find
            .descendant(
              of: find.byType(TrendsScreen),
              matching: find.text('體重與飲食'),
            )
            .first,
      );
      // Below the insights on a phone, so scrolled to; only the
      // horizontal positions are compared.
      await tester.dragUntilVisible(
        find.text('長期走向'),
        find.byType(CustomScrollView).hitTestable().first,
        const Offset(0, -200),
      );
      final longRun = tester.getRect(
        find.descendant(
          of: find.byType(TrendsScreen),
          matching: find.text('長期走向'),
        ),
      );
      expect(
        longRun.left >= changes.right,
        isWide,
        reason: '$window: side by side only when wide',
      );
      await disposeTree(tester);
    }
  });

  testWidgets('a section label sits the page spacing above its card', (
    tester,
  ) async {
    double gapUnder(String label) {
      final labelRect = tester.getRect(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(SectionLabel),
        ),
      );
      final card = find
          .byType(GroupedCard)
          .evaluate()
          .map((element) => tester.getRect(find.byWidget(element.widget)));
      return card
          .where((rect) => rect.top >= labelRect.bottom)
          .map((rect) => rect.top - labelRect.bottom)
          .reduce((a, b) => a < b ? a : b);
    }

    await pumpScreen(tester, const MeScreen(), store: _store());
    expect(
      gapUnder('功能'),
      pageItemSpacing,
      reason: 'label and card as page elements',
    );
    await disposeTree(tester);

    await pumpScreen(tester, const PrivacyScreen(), store: _store());
    expect(
      gapUnder('儲存'),
      pageItemSpacing,
      reason: 'label and card in a PageSection',
    );
    await disposeTree(tester);
  });

  testWidgets('the nutrients of the day show their full names on a phone', (
    tester,
  ) async {
    final store = _store();
    await pumpScreen(tester, const TodayScreen(), store: store, window: phone);
    final line = tester.getSize(find.text('蛋白質')).height;
    for (final name in ['碳水化合物', '膳食纖維']) {
      expect(
        tester.getSize(find.text(name)).height,
        line,
        reason: '$name fits on one line',
      );
    }
    await disposeTree(tester);
  });

  testWidgets('key-value rows end every value on the same edge', (
    tester,
  ) async {
    await pumpScreen(tester, const PrivacyScreen(), store: _store());
    final rights = {
      for (final value in ['只在這台裝置', '可復原', '清除所有紀錄'])
        tester.getRect(find.text(value)).right,
    };
    expect(rights, hasLength(1), reason: 'values align to the trailing edge');
    await disposeTree(tester);
  });

  testWidgets('a footer button keeps to the readable width', (tester) async {
    await pumpScreen(
      tester,
      const WeightEntryScreen(),
      store: _store(),
      window: tablet,
    );

    final button = tester.getRect(find.byType(PrimaryButton));
    expect(
      button.width,
      lessThanOrEqualTo(readableMaxWidth - AppSpacing.screenGutter * 2 + 0.01),
    );
    expect(
      button.center.dx,
      moreOrLessEquals(tablet.size.width / 2, epsilon: 0.5),
    );
    await disposeTree(tester);
  });

  group('list and detail', () {
    testWidgets('a picked page opens beside the list, and the next replaces '
        'it', (tester) async {
      final store = _store();
      await pumpScreen(tester, const HomeShell(), store: store, window: tablet);
      store.selectTab(HomeTab.me);
      await tester.pumpAndSettle();
      expect(find.text('未選取項目'), findsOneWidget);

      await _tapRow(tester, '隱私說明');

      final list = tester.getRect(find.byType(MeScreen));
      final detail = tester.getRect(find.byType(PrivacyScreen));
      expect(detail.left, greaterThanOrEqualTo(list.right));
      expect(find.byType(MeScreen).hitTestable(), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(PrivacyScreen),
          matching: find.byTooltip('返回'),
        ),
        findsNothing,
        reason: 'the list is right beside it; there is nothing to go back to',
      );

      await _tapRow(tester, '匯出');

      expect(find.byType(ExportScreen), findsOneWidget);
      expect(find.byType(PrivacyScreen), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('scrolling the page beside the list leaves the dock alone', (
      tester,
    ) async {
      final store = _store();
      await pumpScreen(tester, const HomeShell(), store: store, window: tablet);
      store.selectTab(HomeTab.me);
      await tester.pumpAndSettle();
      await _tapRow(tester, '隱私說明');
      bool isMinimized() => tester
          .widget<AppBottomChrome>(find.byType(AppBottomChrome))
          .isMinimized;

      await tester.drag(
        find.descendant(
          of: find.byType(PrivacyScreen),
          matching: find.byType(CustomScrollView),
        ),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(isMinimized(), isFalse, reason: 'the dock is on the list pane');

      await tester.drag(
        find.descendant(
          of: find.byType(MeScreen),
          matching: find.byType(CustomScrollView),
        ),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(isMinimized(), isTrue, reason: 'its own pane still moves it');
      await disposeTree(tester);
    });

    testWidgets('what the add menu opens goes beside the list', (tester) async {
      final store = _store();
      await pumpScreen(tester, const HomeShell(), store: store, window: tablet);

      await tester.tap(find.byKey(const ValueKey('dock-center-action')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(quickLogMenuKey),
          matching: find.text('體重'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byType(WeightEntryScreen)).left,
        greaterThanOrEqualTo(tester.getRect(find.byType(TodayScreen)).right),
      );
      expect(find.byType(TodayScreen).hitTestable(), findsWidgets);
      await disposeTree(tester);
    });

    testWidgets('a session opened and finished from the dock stays beside '
        'the list', (tester) async {
      final store = _store()..startWorkout();
      await pumpScreen(tester, const HomeShell(), store: store, window: tablet);
      final list = tester.getRect(find.byType(TodayScreen));

      await tester.tap(find.textContaining('訓練進行中 ·'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.getRect(find.byType(ActiveWorkoutScreen)).left,
        greaterThanOrEqualTo(list.right),
      );

      await tester.tap(find.byTooltip('結束訓練').first);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('結束並儲存'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.getRect(find.byType(WorkoutSummaryScreen)).left,
        greaterThanOrEqualTo(list.right),
      );
      await disposeTree(tester);
    });

    testWidgets('the exercise library opens beside 我的', (tester) async {
      final store = _store();
      await pumpScreen(tester, const HomeShell(), store: store, window: tablet);
      store.selectTab(HomeTab.me);
      await tester.pumpAndSettle();

      await _tapRow(tester, '動作庫');

      final detail = tester.getRect(find.byType(ExercisePickerScreen));
      expect(
        detail.left,
        greaterThanOrEqualTo(tester.getRect(find.byType(MeScreen)).right),
      );
      // The detail pane keeps the list's gutter instead of centring a
      // narrower column in its own width.
      final card = tester.getRect(
        find
            .descendant(
              of: find.byType(ExercisePickerScreen),
              matching: find.byType(AppCard),
            )
            .first,
      );
      expect(card.left - detail.left, AppSpacing.screenGutter);
      expect(detail.right - card.right, AppSpacing.screenGutter);
      await disposeTree(tester);
    });

    testWidgets('below two panes it is pushed over the list', (tester) async {
      final store = _store();
      const medium = WindowCase('839 × 900', Size(839, 900));
      await pumpScreen(tester, const HomeShell(), store: store, window: medium);
      store.selectTab(HomeTab.me);
      await tester.pumpAndSettle();

      await _tapRow(tester, '隱私說明');

      expect(tester.getRect(find.byType(PrivacyScreen)).left, 0);
      expect(find.byTooltip('返回'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('narrowing the window keeps the open page in front', (
      tester,
    ) async {
      final store = _store();
      await pumpScreen(tester, const HomeShell(), store: store, window: tablet);
      store.selectTab(HomeTab.me);
      await tester.pumpAndSettle();
      await _tapRow(tester, '隱私說明');

      useWindow(tester, phone);
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyScreen), findsOneWidget);
      expect(tester.getRect(find.byType(PrivacyScreen)).width, phoneSize.width);
      expect(find.byTooltip('返回'), findsOneWidget);
      await disposeTree(tester);
    });
  });

  testWidgets('resizing in and out of two panes keeps the list', (
    tester,
  ) async {
    final store = _store();
    await pumpScreen(tester, const HomeShell(), store: store);
    store.selectTab(HomeTab.me);
    await tester.pumpAndSettle();
    State list() => tester.state(
      find.descendant(
        of: find.byType(MeScreen),
        matching: find.byType(CollapsingScrollView),
      ),
    );
    final before = list();

    useWindow(tester, tablet);
    await tester.pumpAndSettle();
    expect(find.text('未選取項目'), findsOneWidget);
    expect(
      list(),
      same(before),
      reason: 'the list moved beside the pane instead of being rebuilt',
    );

    useWindow(tester, phone);
    await tester.pumpAndSettle();
    expect(list(), same(before));
    await disposeTree(tester);
  });

  group('folds and hinges', () {
    testWidgets('a page stays on one side of a bent fold', (tester) async {
      await pumpScreen(
        tester,
        const HomeShell(),
        store: _store(),
        window: _bookPosture,
      );

      final cards = _cardRects(tester);
      expect(cards, isNotEmpty);
      for (final card in cards) {
        expect(card.right, lessThanOrEqualTo(420));
      }
      await disposeTree(tester);
    });

    testWidgets('a flat fold is only a crease', (tester) async {
      await pumpScreen(
        tester,
        const PrivacyScreen(),
        store: _store(),
        window: _flatFold,
      );

      final column = tester.getRect(find.byType(Gutter).first);
      expect(
        column.left < 420 && column.right > 420,
        isTrue,
        reason: 'the column is centred as if the fold were not there',
      );
      await disposeTree(tester);
    });

    testWidgets('a narrow foldable opened like a book shows two panes, one '
        'each side', (tester) async {
      final store = _store();
      await pumpScreen(
        tester,
        const HomeShell(),
        store: store,
        window: _galaxyFold(DisplayFeatureState.postureHalfOpened),
      );
      store.selectTab(HomeTab.me);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(SplitDock)).center.dx,
        moreOrLessEquals(345 / 2, epsilon: 0.5),
        reason: 'the dock is on the main page, left of the fold',
      );

      await _tapRow(tester, '隱私說明');

      expect(tester.getRect(find.byType(MeScreen)).right, 345);
      expect(
        tester.getRect(find.byType(PrivacyScreen)).left,
        greaterThanOrEqualTo(345),
      );
      await disposeTree(tester);
    });

    testWidgets('the same foldable opened flat is one page', (tester) async {
      final store = _store();
      await pumpScreen(
        tester,
        const HomeShell(),
        store: store,
        window: _galaxyFold(DisplayFeatureState.postureFlat),
      );
      store.selectTab(HomeTab.me);
      await tester.pumpAndSettle();

      expect(find.text('未選取項目'), findsNothing);
      expect(tester.getRect(find.byType(MeScreen)).width, 690);
      await disposeTree(tester);
    });

    testWidgets('a punch-hole camera is not a fold', (tester) async {
      // A Nothing Phone (3): its camera cutout is taller than it is wide,
      // which Flutter's avoid-bounds rule alone would read as a divide.
      const punchHole = WindowCase(
        'punch-hole phone',
        Size(420, 933),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTRB(192, 0, 228, 54),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );
      final store = _store();
      await pumpScreen(
        tester,
        const HomeShell(),
        store: store,
        window: punchHole,
      );
      store.selectTab(HomeTab.me);
      await tester.pumpAndSettle();

      expect(find.text('未選取項目'), findsNothing);
      expect(tester.getRect(find.byType(MeScreen)).width, 420);
      await disposeTree(tester);
    });

    testWidgets('list and detail meet at the hinge', (tester) async {
      final store = _store();
      await pumpScreen(
        tester,
        const HomeShell(),
        store: store,
        window: _dualScreen,
      );
      store.selectTab(HomeTab.me);
      await tester.pumpAndSettle();
      await _tapRow(tester, '隱私說明');

      expect(tester.getRect(find.byType(MeScreen)).right, 540);
      expect(tester.getRect(find.byType(PrivacyScreen)).left, 574);
      await disposeTree(tester);
    });

    testWidgets('the dock keeps off the hinge', (tester) async {
      await pumpScreen(
        tester,
        const HomeShell(),
        store: _store(),
        window: _dualScreen,
      );

      final dock = tester.getRect(find.byType(SplitDock));
      expect(dock.right, lessThanOrEqualTo(540));
      expect(dock.center.dx, moreOrLessEquals(270, epsilon: 0.5));
      await disposeTree(tester);
    });

    testWidgets('a toast keeps off the hinge', (tester) async {
      await pumpScreen(
        tester,
        const HomeShell(),
        store: _store(),
        window: _dualScreen,
      );

      showToast(tester.element(find.byType(HomeShell)), '已記錄');
      await tester.pumpAndSettle();

      expect(tester.getRect(find.text('已記錄')).right, lessThanOrEqualTo(540));
      await disposeTree(tester);
    });
  });
}
