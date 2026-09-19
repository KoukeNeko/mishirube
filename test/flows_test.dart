import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import 'support/harness.dart';

const _pageTransition = Duration(milliseconds: 600);

const _scrollStep = Offset(0, -200);

Future<void> _tapText(WidgetTester tester, String text) async {
  // Lazy lists only build what is on screen, so scroll until it exists.
  if (find.text(text).evaluate().isEmpty) {
    await tester.dragUntilVisible(
      find.text(text),
      find.byType(CustomScrollView).hitTestable().first,
      _scrollStep,
    );
  }
  final target = find.text(text).first;
  if (Scrollable.maybeOf(tester.element(target)) != null) {
    // Center it so fixed footers cannot cover the tap point.
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
    await tester.pump();
  }
  await tester.tap(find.text(text).first);
  await tester.pump();
  await tester.pump(_pageTransition);
}

void main() {
  testWidgets('onboarding → workout → rest → summary → back to Today', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final clock = FakeClock();
    final store = AppStore(clock: clock.now);
    await tester.pumpWidget(MishirubeApp(store: store));

    expect(find.text('你想用它做什麼？'), findsWidgets);
    await _tapText(tester, '繼續');

    expect(find.text('今天'), findsWidgets);
    await _tapText(tester, '開始訓練');
    expect(find.text('完成這一組'), findsOneWidget);
    expect(find.text('槓鈴深蹲'), findsOneWidget);

    await _tapText(tester, '完成這一組');
    expect(find.text('休息中'), findsOneWidget);
    expect(find.text('新紀錄'), findsOneWidget);

    await _tapText(tester, '跳過休息');
    expect(store.activeWorkout!.completedSets, 1);

    clock.advance(const Duration(minutes: 30));
    await _tapText(tester, '結束');
    expect(find.text('回到今天'), findsOneWidget);
    expect(store.lastFinishedWorkout, isNotNull);

    await _tapText(tester, '回到今天');
    expect(find.text('下肢 A 已完成'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('photo → confirm meal → split dish → undo', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..cyclePhase();
    await tester.pumpWidget(MishirubeApp(store: store));

    expect(find.text('記錄午餐'), findsOneWidget);
    await _tapText(tester, '拍照');
    expect(find.text('確認這一餐'), findsWidgets);

    await _tapText(tester, '多一點');
    expect(find.text('~665'), findsOneWidget);

    await _tapText(tester, '確認並存入');
    expect(store.isLunchLogged, isTrue);
    expect(find.text('飲食'), findsWidgets);

    await _tapText(tester, '拆成獨立紀錄');
    expect(find.textContaining('要把這道料理拆成 5 筆'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '拆成獨立紀錄'));
    await tester.pump();
    await tester.pump(_pageTransition);
    expect(find.text('雞肉照燒蛋全麥三明治'), findsNothing);

    await tester.tap(find.text('復原'));
    await tester.pump();
    expect(find.text('雞肉照燒蛋全麥三明治'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets(
    'exercise search with no match offers to drop the equipment filter',
    (tester) async {
      usePhoneViewport(tester);
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      await tester.pumpWidget(MishirubeApp(store: store));

      await _tapText(tester, '下肢 A');
      await _tapText(tester, '加入動作');
      await tester.enterText(find.byType(TextField), '史密斯深蹲');
      await tester.pump();
      expect(find.text('沒有符合的動作'), findsOneWidget);

      await _tapText(tester, '移除器材篩選再找一次');
      expect(find.text('史密斯機深蹲'), findsOneWidget);

      await _tapText(tester, '史密斯機深蹲');
      await _tapText(tester, '加入 1 個動作');
      expect(store.routine.exercises.last.exercise.name, '史密斯機深蹲');
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    },
  );

  testWidgets('month popover hangs under its button and blocks the future', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..selectTab(HomeTab.log);
    await tester.pumpWidget(MishirubeApp(store: store));
    await tester.pump();

    final button = tester.getRect(
      find.ancestor(
        of: find.text('9月').hitTestable(),
        matching: find.byType(HeaderAction),
      ),
    );
    await tester.tap(find.text('9月').hitTestable());
    await tester.pump();
    await tester.pump(_pageTransition);
    final september = find.text('9 月');
    final popover = tester.getRect(
      find
          .ancestor(
            of: find.byType(CupertinoPicker).first,
            matching: find.byType(ChromeSurface),
          )
          .first,
    );
    expect(popover.top, button.bottom + 8, reason: 'hangs under the button');
    expect(popover.right, button.right);

    // A future month settles back to the latest one.
    await tester.drag(september, const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(find.text('2026 年 9 月'), findsOneWidget);

    await tester.drag(september, const Offset(0, 60));
    await tester.pumpAndSettle();
    expect(find.text('2026 年 8 月'), findsOneWidget);
    expect(find.text('8月'), findsOneWidget);

    // Tapping outside closes it.
    await tester.tapAt(const Offset(20, 600));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPicker), findsNothing);
    expect(find.text('8 月沒有紀錄'), findsOneWidget);
    await disposeTree(tester);
  });
}
