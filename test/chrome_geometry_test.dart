import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app.dart';
import 'package:mishirube/app/app_store.dart';
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
      // The first item is the local-first banner.
      final firstItem = tester.getRect(find.byType(InfoBanner).first);
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
}
