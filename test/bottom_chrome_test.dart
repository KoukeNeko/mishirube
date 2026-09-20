import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/features/me/import_screen.dart';
import 'package:mishirube/features/shell/bottom_chrome/chrome_metrics.dart';
import 'package:mishirube/features/shell/bottom_chrome/press_feedback.dart';
import 'package:mishirube/features/shell/bottom_chrome/quick_log_menu.dart';
import 'package:mishirube/features/shell/bottom_chrome/split_dock.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

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

  testWidgets('the menu is evenly spaced and folds back on close', (
    tester,
  ) async {
    await _pumpApp(tester, FakeClock());

    await tester.tap(find.byKey(_centerAction));
    await _settleFor(tester);
    final pills = find.descendant(
      of: find.byKey(quickLogMenuKey),
      matching: find.byType(InkWell),
    );
    // One rhythm all the way down, × included.
    final rows = [
      for (var i = 0; i < pills.evaluate().length; i++)
        tester.getRect(pills.at(i)),
      tester.getRect(find.byTooltip('關閉')),
    ];
    final gaps = {
      for (var i = 1; i < rows.length; i++)
        (rows[i].top - rows[i - 1].bottom).round(),
    };
    expect(gaps, hasLength(1), reason: 'the spacing is even, $gaps');

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

    await tester.tap(find.text('結束並儲存'));
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

        await tester.tap(find.bySemanticsLabel('紀錄'));
        await _settleFor(tester);
        await tester.tap(find.bySemanticsLabel('紀錄'));
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
          tester
              .widget<ImageFiltered>(find.byType(ImageFiltered).first)
              .enabled,
          isTrue,
          reason: 'the app behind the menu is blurred',
        );
        double centerOpacity() => tester
            .widget<Opacity>(
              find.byKey(const ValueKey('dock-center-visibility')),
            )
            .opacity;
        expect(centerOpacity(), 0, reason: '× stands in for the blurred「+」');

        await tester.tap(find.byTooltip('關閉'));
        await _settleFor(tester);
        expect(contentRect(tester).width, phoneSize.width);
        expect(
          tester
              .widget<ImageFiltered>(find.byType(ImageFiltered).first)
              .enabled,
          isFalse,
          reason: 'no filter left running once closed',
        );
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
        const ImportScreen(),
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

    final sizes = tester
        .widgetList<Icon>(find.byIcon(Icons.add))
        .map((icon) => icon.size)
        .toSet();
    expect(find.byIcon(Icons.add), findsNWidgets(2), reason: '「+」and ×');
    expect(sizes, hasLength(1));
    await disposeTree(tester);
  });
}
