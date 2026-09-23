import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/features/goal/goal_screen.dart';
import 'package:mishirube/features/journal/weight_entry_screen.dart';
import 'package:mishirube/features/training/active_workout_screen.dart';
import 'package:mishirube/features/shell/bottom_chrome/split_dock.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import 'support/harness.dart';

const _settle = Duration(milliseconds: 800);
final _visibleScrollView = find.byType(CustomScrollView).hitTestable();

/// The header's glass layer fills the whole header box (other tabs are
/// offstage, so this is the visible tab's header).
final _header = find.byType(ScrollEdgeGlass).first;

/// 我的 is long enough to scroll and has neither a pinned control nor
/// auto-hide, so its header shows the plain geometry.
Future<AppStore> _pumpShell(
  WidgetTester tester, {
  HomeTab tab = HomeTab.me,
}) async {
  usePhoneViewport(tester);
  final store = AppStore(clock: FakeClock().now, isOnboarded: true)
    ..selectTab(tab);
  await tester.pumpWidget(MishirubeApp(store: store));
  await tester.pump(_settle);
  return store;
}

const _slop = 20.0;
const _steps = 10;

/// Scrolls exactly [dy] like a finger that stops before lifting: past the
/// touch slop first, then in small steps, then a pause so nothing flings.
Future<void> _dragAndSettle(WidgetTester tester, double dy) async {
  final gesture = await tester.startGesture(
    tester.getCenter(_visibleScrollView),
  );
  await gesture.moveBy(const Offset(0, -_slop));
  for (var i = 0; i < _steps; i++) {
    await gesture.moveBy(Offset(0, -dy / _steps));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump(const Duration(milliseconds: 300));
  await gesture.up();
  await tester.pump();
  await tester.pump(_settle);
  await tester.pump(_settle);
}

void main() {
  _dialogActionLayoutTests();
  final iosOnly = TargetPlatformVariant.only(TargetPlatform.iOS);

  group('iOS dock follows Liquid Glass proportions', () {
    testWidgets(
      '62pt dock dips into the home indicator area',
      variant: iosOnly,
      (tester) async {
        await _pumpShell(tester);

        final dock = tester.getRect(find.byType(SplitDock));
        expect(dock.height, 62);
        expect(phoneSize.height - dock.bottom, phoneBottomInset - 13);
        await disposeTree(tester);
      },
    );

    testWidgets(
      'minimised dock is 48pt and loses its labels',
      variant: iosOnly,
      (tester) async {
        await _pumpShell(tester);

        await _dragAndSettle(tester, 400);

        final dock = tester.getRect(find.byType(SplitDock));
        expect(dock.height, 48);
        expect(phoneSize.height - dock.bottom, phoneBottomInset - 6);
        expect(
          find.descendant(
            of: find.byType(SplitDock),
            matching: find.text('趨勢'),
          ),
          findsNothing,
        );
        await disposeTree(tester);
      },
    );
  });

  testWidgets('Android dock stays above the gesture inset', (tester) async {
    await _pumpShell(tester);

    final dock = tester.getRect(find.byType(SplitDock));
    expect(dock.height, 64);
    expect(phoneSize.height - dock.bottom, phoneBottomInset + 8);
    await disposeTree(tester);
  });

  final bothPlatforms = TargetPlatformVariant({
    TargetPlatform.iOS,
    TargetPlatform.android,
  });
  ToolbarMetrics toolbarMetrics() => defaultTargetPlatform == TargetPlatform.iOS
      ? ToolbarMetrics.ios
      : ToolbarMetrics.android;

  testWidgets(
    'collapsed bar has the platform height and a 16pt gap to content',
    variant: bothPlatforms,
    (tester) async {
      final toolbar = toolbarMetrics();
      await _pumpShell(tester);
      final largeBlock =
          tester.getRect(_header).height - phoneTopInset - toolbar.height;

      // Past halfway, so it snaps to exactly collapsed.
      await _dragAndSettle(tester, largeBlock * 0.7);

      final header = tester.getRect(_header);
      expect(header.height, phoneTopInset + toolbar.height);
      // The first item is the first section's label.
      final firstItem = tester.getRect(find.byType(SectionLabel).first);
      expect(firstItem.top - header.bottom, 16);
      await disposeTree(tester);
    },
  );

  testWidgets('large title snaps instead of resting half collapsed', (
    tester,
  ) async {
    final toolbar = toolbarMetrics();
    await _pumpShell(tester);
    final expanded = tester.getRect(_header);

    await _dragAndSettle(tester, 12);
    expect(
      tester.getRect(_header).height,
      expanded.height,
      reason: 'a small drag snaps back open',
    );

    final largeBlock = expanded.height - phoneTopInset - toolbar.height;
    await _dragAndSettle(tester, largeBlock * 0.7);
    expect(
      tester.getRect(_header).height,
      phoneTopInset + toolbar.height,
      reason: 'past halfway it snaps shut',
    );
    await disposeTree(tester);
  });

  testWidgets(
    'title and actions share the control row centre',
    variant: bothPlatforms,
    (tester) async {
      final toolbar = toolbarMetrics();
      await _pumpShell(tester, tab: HomeTab.today);
      // iOS: the row hangs right under the safe area with space below it,
      // so its centre is not the centre of the whole bar.
      final rowCenter = phoneTopInset + toolbar.controlRowHeight / 2;

      final action = find.byType(HeaderAction).first;
      final pill = tester.getRect(
        find.descendant(of: action, matching: find.byType(Material)).first,
      );
      final title = tester.getRect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data == '今天' &&
              widget.style == compactTitleStyle,
        ),
      );

      expect(tester.getRect(action).height, toolbar.actionHitSize);
      expect(pill.height, toolbar.actionVisualSize);
      expect(pill.center.dy, closeTo(rowCenter, 0.5));
      expect(title.center.dy, closeTo(rowCenter, 0.5));
      await disposeTree(tester);
    },
  );

  testWidgets(
    'every page shrinks to the same bar height',
    variant: bothPlatforms,
    (tester) async {
      final toolbar = toolbarMetrics();
      Future<double> shrunkHeight() async {
        for (var i = 0; i < 3; i++) {
          await _dragAndSettle(tester, 600);
        }
        return tester
            .getRect(find.byType(ScrollEdgeGlass).hitTestable().first)
            .height;
      }

      final store = await _pumpShell(tester);
      for (final tab in HomeTab.values) {
        store.selectTab(tab);
        await tester.pump(_settle);
        expect(
          await shrunkHeight(),
          phoneTopInset + toolbar.height,
          reason: '$tab',
        );
      }

      // Without a compact bar the pinned switch takes the toolbar's place.
      store.selectTab(HomeTab.log);
      await tester.pump(_settle);
      final chip = tester.getRect(find.text('時間軸').hitTestable());
      expect(
        chip.center.dy,
        closeTo(phoneTopInset + toolbar.controlRowHeight / 2, 0.5),
      );
      await disposeTree(tester);

      await pumpScreen(tester, const WeightEntryScreen(), store: store);
      expect(await shrunkHeight(), phoneTopInset + toolbar.height);
      await disposeTree(tester);
    },
  );

  testWidgets(
    'header buttons, segmented control and chips share one height',
    variant: bothPlatforms,
    (tester) async {
      await _pumpShell(tester, tab: HomeTab.log);
      final toolbar = ToolbarMetrics.of(tester.element(_header));

      double pillHeight(Finder label) => tester
          .getRect(
            find.ancestor(of: label, matching: find.byType(Material)).first,
          )
          .height;

      expect(pillHeight(find.text('9月')), toolbar.actionVisualSize);
      expect(pillHeight(find.text('時間軸')), toolbar.actionVisualSize);
      expect(pillHeight(find.text('訓練').first), toolbar.actionVisualSize);
      await disposeTree(tester);
    },
  );

  testWidgets(
    'pinned control keeps the content gap below the large title',
    variant: bothPlatforms,
    (tester) async {
      await _pumpShell(tester, tab: HomeTab.log);

      final subtitle = tester.getRect(find.text('2026 年 9 月').first);
      final control = tester.getRect(
        find
            .ancestor(of: find.text('時間軸'), matching: find.byType(Material))
            .first,
      );
      expect(control.top - subtitle.bottom, AppSpacing.md);
      await disposeTree(tester);
    },
  );

  testWidgets(
    'toolbar slides away above the pinned control instead of under it',
    variant: iosOnly,
    (tester) async {
      await _pumpShell(tester, tab: HomeTab.log);
      final toolbar = ToolbarMetrics.of(tester.element(_header));
      final delegate =
          tester
                  .widget<SliverPersistentHeader>(
                    find
                        .descendant(
                          of: _visibleScrollView,
                          matching: find.byType(SliverPersistentHeader),
                        )
                        .first,
                  )
                  .delegate
              as CollapsingHeaderDelegate;

      Rect pill(String label) => tester.getRect(
        find
            .ancestor(of: find.text(label), matching: find.byType(Material))
            .first,
      );

      // Hold the finger part-way through the toolbar scrolling away.
      final gesture = await tester.startGesture(
        tester.getCenter(_visibleScrollView),
      );
      await gesture.moveBy(const Offset(0, -_slop));
      for (final dy in [delegate.largeHeight + 15, 15.0]) {
        await gesture.moveBy(Offset(0, -dy));
        await tester.pump();
        expect(
          pill('時間軸').top - pill('9月').bottom,
          toolbar.height - toolbar.controlRowHeight,
        );
      }
      await gesture.up();
      await disposeTree(tester);
    },
  );

  testWidgets('a day without records keeps the header collapsed', (
    tester,
  ) async {
    await _pumpShell(tester, tab: HomeTab.log);
    await tester.tap(find.text('月曆').hitTestable());
    await tester.pump(_settle);
    // Past halfway, so it snaps fully collapsed.
    await _dragAndSettle(tester, 150);
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(of: _visibleScrollView, matching: find.byType(Scrollable))
          .first,
    );
    final range =
        (tester
                    .widget<SliverPersistentHeader>(
                      find
                          .descendant(
                            of: _visibleScrollView,
                            matching: find.byType(SliverPersistentHeader),
                          )
                          .first,
                    )
                    .delegate
                as CollapsingHeaderDelegate)
            .collapseRange;
    expect(scrollable.position.pixels, greaterThanOrEqualTo(range));

    await tester.tap(find.text('7').hitTestable());
    await tester.pump(_settle);
    expect(find.text('這天沒有紀錄。'), findsOneWidget);
    expect(
      scrollable.position.pixels,
      greaterThanOrEqualTo(range),
      reason: 'the header is still fully collapsed',
    );
    await disposeTree(tester);
  });

  testWidgets('action chips are full pills with button semantics', (
    tester,
  ) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..startWorkout();
    await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);
    final handle = tester.ensureSemantics();

    final chip = find.widgetWithText(ChipButton, '熱身');
    expect(
      tester.getSize(chip).height,
      ToolbarMetrics.of(tester.element(chip)).actionVisualSize,
    );
    expect(
      tester.getSemantics(chip),
      matchesSemantics(label: '加入熱身組', isButton: true, hasTapAction: true),
    );
    handle.dispose();
    await disposeTree(tester);
  });

  testWidgets('custom buttons stay activatable by screen readers', (
    tester,
  ) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..selectTab(HomeTab.log);
    usePhoneViewport(tester);
    await tester.pumpWidget(MishirubeApp(store: store));
    await tester.pump();
    final handle = tester.ensureSemantics();

    // Each wraps its visuals in Semantics(excludeSemantics: true), which
    // would otherwise drop the child's tap action.
    for (final label in ['今天', '新增紀錄', '搜尋紀錄']) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label).last),
        isSemantics(isButton: true, hasTapAction: true),
        reason: label,
      );
    }
    handle.dispose();
    await disposeTree(tester);
  });

  testWidgets(
    'header actions keep the page gutter, like page content',
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    (tester) async {
      await _pumpShell(tester, tab: HomeTab.log);

      final search = tester.getRect(
        find.bySemanticsLabel('搜尋紀錄').hitTestable(),
      );
      expect(phoneSize.width - search.right, AppSpacing.screenGutter);
      expect(
        tester.getRect(find.text('紀錄').hitTestable().first).left,
        AppSpacing.screenGutter,
      );
      await disposeTree(tester);
    },
  );

  testWidgets('both ends of the toolbar keep the same gutter', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..backend.goal.setGoal(3, applyThisWeek: true);
    await pumpScreen(tester, const GoalScreen(), store: store);

    final back = tester.getRect(find.bySemanticsLabel('返回').hitTestable());
    final action = tester.getRect(
      find.bySemanticsLabel('調整每週目標').hitTestable(),
    );
    expect(back.left, AppSpacing.screenGutter);
    expect(phoneSize.width - action.right, AppSpacing.screenGutter);

    final glass = find.byType(ChromeSurface);
    final leadingGlass = tester.getRect(glass.first);
    final trailingGlass = tester.getRect(glass.at(1));
    expect(
      leadingGlass.left,
      phoneSize.width - trailingGlass.right,
      reason: 'the two pills sit the same distance from their edges',
    );
    expect(leadingGlass.top, trailingGlass.top);
    await disposeTree(tester);
  });

  testWidgets('the back control is the same glass as the actions', (
    tester,
  ) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const WeightEntryScreen(), store: store);
    final back = find.bySemanticsLabel('返回');

    final surface = find.descendant(
      of: back,
      matching: find.byType(ChromeSurface),
    );
    expect(tester.widget<ChromeSurface>(surface.first).refracts, isTrue);
    expect(
      tester.getSize(back).shortestSide,
      greaterThanOrEqualTo(
        ToolbarMetrics.of(tester.element(back)).actionHitSize,
      ),
      reason: 'the touch target stays a full action, glass or not',
    );
    await disposeTree(tester);
  });

  testWidgets('going back stays silent', (tester) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const WeightEntryScreen(), store: store);

    await tester.tap(find.bySemanticsLabel('返回'));
    await tester.pump();

    expect(haptics, isEmpty, reason: 'back controls feel like the system\'s');
    await disposeTree(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}

/// The dialog decides its own action layout: two labels that fit sit side
/// by side, anything else stacks. Counting characters would break on a
/// longer translation or at a larger text size.
void _dialogActionLayoutTests() {
  Future<void> pumpDialog(
    WidgetTester tester,
    List<DialogAction> actions, {
    double textScale = 1,
    bool isChoiceList = false,
  }) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: AppDialog(
            title: '訓練名稱',
            actions: actions,
            isChoiceList: isChoiceList,
          ),
        ),
      ),
      store: store,
    );
  }

  List<DialogAction> saveOrCancel() => [
    DialogAction(label: '儲存', tone: DialogTone.primary, onTap: () {}),
    DialogAction(label: '取消', onTap: () {}),
  ];

  testWidgets('a long list of choices scrolls inside the dialog', (
    tester,
  ) async {
    await pumpDialog(tester, [
      for (var index = 0; index < 40; index++)
        DialogAction(label: '模型 $index', onTap: () {}),
    ], isChoiceList: true);

    final screen =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final dialog = tester.getRect(find.byType(ChromeSurface).first);
    expect(dialog.top, greaterThanOrEqualTo(0));
    expect(
      dialog.bottom,
      lessThanOrEqualTo(screen),
      reason: 'the dialog stays on screen however many choices there are',
    );
    expect(find.text('訓練名稱'), findsOneWidget, reason: 'the title is not cut');

    // The last choice is reached by scrolling the list, not by the
    // dialog growing past the screen.
    await tester.dragUntilVisible(
      find.text('模型 39'),
      find.byType(SingleChildScrollView).first,
      const Offset(0, -200),
    );
    expect(find.text('模型 39'), findsOneWidget);
  });

  testWidgets('two short choices sit side by side, cancel leading', (
    tester,
  ) async {
    await pumpDialog(tester, saveOrCancel());

    final save = tester.getCenter(find.text('儲存'));
    final cancel = tester.getCenter(find.text('取消'));
    expect(save.dy, cancel.dy, reason: 'one row, not two');
    expect(
      cancel.dx,
      lessThan(save.dx),
      reason: 'the way out is leading, what was asked for is trailing',
    );
    await disposeTree(tester);
  });

  testWidgets('two options of equal standing stack in their order', (
    tester,
  ) async {
    await pumpDialog(tester, [
      DialogAction(label: '大杯', onTap: () {}),
      DialogAction(label: '特大杯', onTap: () {}),
    ], isChoiceList: true);

    expect(
      tester.getCenter(find.text('大杯')).dy,
      lessThan(tester.getCenter(find.text('特大杯')).dy),
      reason:
          'a list of options is read top to bottom, not as a way out '
          'and an answer side by side',
    );
    await disposeTree(tester);
  });

  testWidgets('a pair that no longer fits stacks itself', (tester) async {
    List<DialogAction> longPair() => [
      DialogAction(
        label: '放棄已選的動作',
        tone: DialogTone.destructive,
        onTap: () {},
      ),
      DialogAction(label: '繼續選擇', onTap: () {}),
    ];

    await pumpDialog(tester, longPair());
    expect(
      tester.getCenter(find.text('放棄已選的動作')).dy,
      tester.getCenter(find.text('繼續選擇')).dy,
      reason: 'at the normal text size the pair still fits',
    );
    await disposeTree(tester);

    await pumpDialog(tester, longPair(), textScale: 1.6);
    expect(
      tester.getCenter(find.text('放棄已選的動作')).dy,
      isNot(tester.getCenter(find.text('繼續選擇')).dy),
      reason: 'larger text has to fall back to stacked',
    );
    await disposeTree(tester);
  });

  testWidgets('three choices always stack', (tester) async {
    await pumpDialog(tester, [
      DialogAction(label: '結束並儲存', tone: DialogTone.primary, onTap: () {}),
      DialogAction(label: '放棄這次訓練', tone: DialogTone.destructive, onTap: () {}),
      DialogAction(label: '繼續訓練', onTap: () {}),
    ]);

    final rows = [
      for (final label in ['結束並儲存', '放棄這次訓練', '繼續訓練'])
        tester.getRect(find.text(label)),
    ];
    expect(rows[0].center.dy, lessThan(rows[1].center.dy));
    expect(rows[1].center.dy, lessThan(rows[2].center.dy));
    expect(
      {for (final row in rows) row.left.round()},
      hasLength(1),
      reason: 'stacked labels line up with each other',
    );
    await disposeTree(tester);
  });
}
