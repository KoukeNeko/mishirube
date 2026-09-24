import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/features/journal/weight_entry_screen.dart';
import 'package:mishirube/features/nutrition/food_search_screen.dart';
import 'package:mishirube/features/shell/bottom_chrome/split_dock.dart';
import 'package:mishirube/features/shell/home_shell.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import 'support/harness.dart';

const _settle = Duration(milliseconds: 400);

Future<void> _settleToast(WidgetTester tester) async {
  // Chrome reports its position after a frame, then the toast moves.
  await tester.pump();
  await tester.pump();
  await tester.pump(_settle);
}

Finder get _toastCard => find
    .ancestor(of: find.text('已加入午餐'), matching: find.byType(ChromeSurface))
    .first;

void main() {
  group('queue', () {
    testWidgets('an undo is not displaced by a plain message', (tester) async {
      final toasts = ToastController();
      var undone = false;

      toasts.showUndo('已拆成獨立紀錄', onUndo: () => undone = true);
      toasts.show('已更新收藏');
      expect(toasts.current!.message, '已拆成獨立紀錄');

      toasts.runAction();
      expect(undone, isTrue);
      expect(toasts.current!.message, '已更新收藏', reason: 'waiting toast next');
      toasts.dispose();
    });

    testWidgets('plain messages replace each other and expire', (tester) async {
      final toasts = ToastController();

      toasts
        ..show('第一則')
        ..show('第二則');
      expect(toasts.current!.message, '第二則');

      await tester.pump(const Duration(milliseconds: 3600));
      expect(toasts.current, isNull);
      toasts.dispose();
    });

    testWidgets('screen-reader navigation keeps an undo until handled', (
      tester,
    ) async {
      final toasts = ToastController()..keepsActionableToasts = true;

      toasts.showUndo('已拆成獨立紀錄', onUndo: () {});
      await tester.pump(const Duration(minutes: 1));

      expect(toasts.current, isNotNull);
      toasts.dispose();
    });
  });

  group('placement', () {
    testWidgets('floats above the dock', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(
        MishirubeApp(
          store: AppStore(clock: FakeClock().now, isOnboarded: true),
        ),
      );
      await tester.pump();

      showToast(tester.element(find.byType(HomeShell)), '已加入午餐');
      await _settleToast(tester);

      final dockTop = tester.getRect(find.byType(SplitDock)).top;
      expect(tester.getRect(_toastCard).bottom, closeTo(dockTop - 10, 0.5));
      await disposeTree(tester);
    });

    testWidgets('floats above a page footer', (tester) async {
      await pumpScreen(
        tester,
        const WeightEntryScreen(),
        store: AppStore(clock: FakeClock().now, isOnboarded: true),
      );

      showToast(tester.element(find.byType(WeightEntryScreen)), '已加入午餐');
      await _settleToast(tester);

      final footerControls = tester.getRect(
        find
            .descendant(
              of: find.byType(BottomActionBar),
              matching: find.byType(ToastObstruction),
            )
            .first,
      );
      expect(
        tester.getRect(_toastCard).bottom,
        closeTo(footerControls.top - 10, 0.5),
      );
      await disposeTree(tester);
    });

    // The food page has no footer, so nothing rides up with the keyboard
    // and the toast's own rule is what is under test.
    testWidgets('a showing toast stays put when the keyboard comes up', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const FoodSearchScreen(),
        store: AppStore(clock: FakeClock().now, isOnboarded: true),
      );
      showToast(tester.element(find.byType(FoodSearchScreen)), '已加入午餐');
      await _settleToast(tester);
      final before = tester.getRect(_toastCard);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await _settleToast(tester);

      expect(
        tester.getRect(_toastCard).top,
        before.top,
        reason:
            'it does not jump over the page title; the keyboard covers '
            'it while the user types, and it is still there afterwards',
      );
      await disposeTree(tester);
    });

    testWidgets('one that appears with the keyboard up sits above it', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const FoodSearchScreen(),
        store: AppStore(clock: FakeClock().now, isOnboarded: true),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();

      showToast(tester.element(find.byType(FoodSearchScreen)), '已加入午餐');
      await _settleToast(tester);

      final card = tester.getRect(_toastCard);
      final keyboardTop = phoneSize.height - 300;
      expect(card.bottom, lessThanOrEqualTo(keyboardTop));
      expect(
        card.bottom,
        greaterThan(keyboardTop - 40),
        reason: 'right above the keyboard, not over the top of the page',
      );
      await disposeTree(tester);
    });
  });

  testWidgets('undo toast shows its countdown and restores the change', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const WeightEntryScreen(),
      store: AppStore(clock: FakeClock().now, isOnboarded: true),
    );
    var undone = false;

    ToastScope.read(tester.element(find.byType(WeightEntryScreen)))
        .showUndo('已拆成獨立紀錄', onUndo: () => undone = true);
    await _settleToast(tester);
    expect(find.text('30s'), findsOneWidget);

    await tester.tap(find.text('復原'));
    await _settleToast(tester);
    expect(undone, isTrue);
    expect(find.text('已拆成獨立紀錄'), findsNothing);
    await disposeTree(tester);
  });
}
