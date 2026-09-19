import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/features/me/import_screen.dart';
import 'package:mishirube/features/onboarding/onboarding_screen.dart';
import 'package:mishirube/features/training/active_workout_screen.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import 'support/harness.dart';

AppStore _store() => AppStore(clock: FakeClock().now, isOnboarded: true);

void _expectFooterReachesBottomEdge(WidgetTester tester, String buttonLabel) {
  final footer = tester.getRect(find.byType(BottomActionBar));
  final button = tester.getRect(find.text(buttonLabel));

  expect(
    footer.bottom,
    phoneSize.height,
    reason: 'footer paints under the home indicator',
  );
  expect(
    button.bottom,
    lessThanOrEqualTo(phoneSize.height - phoneBottomInset),
    reason: 'footer content stays above the home indicator',
  );
}

void main() {
  testWidgets('system bars are transparent with light icons', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(MishirubeApp(store: _store()));
    await tester.pump();

    final style = SystemChrome.latestStyle;
    expect(style?.statusBarColor, Colors.transparent);
    expect(style?.systemNavigationBarColor, Colors.transparent);
    expect(style?.statusBarBrightness, Brightness.dark);
    await disposeTree(tester);
  });

  testWidgets('onboarding footer runs to the bottom edge', (tester) async {
    final store = AppStore(clock: FakeClock().now);
    await pumpScreen(tester, const OnboardingScreen(), store: store);

    _expectFooterReachesBottomEdge(tester, '繼續');
    expect(
      tester.getRect(find.text('你想用它做什麼？').first).top,
      greaterThanOrEqualTo(phoneTopInset),
    );
    await disposeTree(tester);
  });

  testWidgets('detail page footer runs to the bottom edge', (tester) async {
    await pumpScreen(tester, const ImportScreen(), store: _store());

    _expectFooterReachesBottomEdge(tester, '確認匯入');
    expect(
      tester.getRect(find.text('匯入 Strong 資料').first).top,
      greaterThanOrEqualTo(phoneTopInset),
    );
    await disposeTree(tester);
  });

  testWidgets('workout header colour fills the status bar area', (
    tester,
  ) async {
    final store = _store()..startWorkout();
    await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);

    final headerBackground = find.byWidgetPredicate(
      (widget) =>
          widget is ColoredBox && widget.color == AppColors.trainingSurface,
    );
    expect(tester.getRect(headerBackground.first).top, 0);
    expect(
      tester.getRect(find.text('結束')).top,
      greaterThanOrEqualTo(phoneTopInset),
    );
    _expectFooterReachesBottomEdge(tester, '完成這一組');
    await disposeTree(tester);
  });

  testWidgets('last list item can scroll above the home indicator', (
    tester,
  ) async {
    await pumpScreen(tester, const ImportScreen(), store: _store());

    await tester.dragUntilVisible(
      find.text('CSV 檢視'),
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pump();

    final footerTop = tester.getRect(find.byType(BottomActionBar)).top;
    expect(tester.getRect(find.text('CSV 檢視')).bottom, lessThan(footerTop));
    await disposeTree(tester);
  });

  testWidgets('content scrolls behind the status bar under glass', (
    tester,
  ) async {
    final store = AppStore(clock: FakeClock().now);
    await pumpScreen(tester, const OnboardingScreen(), store: store);
    final glass = find.byType(ScrollEdgeGlass);
    double glassOpacity() => tester.widget<ScrollEdgeGlass>(glass).opacity;
    expect(glassOpacity(), 0, reason: 'clear while nothing is underneath');

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pump();

    expect(
      tester.getRect(find.byType(Scrollable).first).top,
      0,
      reason: 'the scroll view itself reaches the top edge',
    );
    expect(glassOpacity(), 1);
    await disposeTree(tester);
  });

  testWidgets('footer floats on a fade that lets taps through', (tester) async {
    final store = AppStore(clock: FakeClock().now);
    await pumpScreen(tester, const OnboardingScreen(), store: store);

    final footer = tester.widget<BottomActionBar>(find.byType(BottomActionBar));
    expect(footer, isNotNull);
    final fade = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(BottomActionBar),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final gradient = (fade.decoration as BoxDecoration).gradient!;
    expect(gradient.colors.first.a, 0, reason: 'no solid bar at the top edge');

    final footerRect = tester.getRect(find.byType(BottomActionBar));
    final before = {...store.enabledModules};
    await tester.tapAt(Offset(footerRect.center.dx, footerRect.top + 6));
    await tester.pump();
    expect(
      store.enabledModules,
      isNot(equals(before)),
      reason: 'the tile under the fade received the tap',
    );
    await disposeTree(tester);
  });

  testWidgets(
    'iOS footer sits as low as the dock',
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    (tester) async {
      await pumpScreen(tester, const ImportScreen(), store: _store());

      final controls = tester.getRect(
        find
            .descendant(
              of: find.byType(BottomActionBar),
              matching: find.byType(ToastObstruction),
            )
            .first,
      );
      // Same rule as the dock: dip 13pt into the home-indicator area.
      expect(phoneSize.height - controls.bottom, phoneBottomInset - 13);
      await disposeTree(tester);
    },
  );
}
