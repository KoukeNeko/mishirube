import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/shell/bottom_chrome/quick_log_menu.dart';
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
    final lunch = store.todayMeals.last;
    expect(lunch.kcal, 665, reason: 'the confirmed estimate is what is kept');
    expect(lunch.qualityTag, '份量為估計');
    expect(
      lunch.dishes.single.components
          .firstWhere((component) => component.name == '美乃滋')
          .amountLabel,
      '~18 g',
      reason: 'the answer replaces the inferred range',
    );
    expect(find.text('飲食'), findsWidgets);

    // Dishes start collapsed; the components appear when one is opened.
    await _tapText(tester, '雞肉照燒蛋全麥三明治');
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
    expect(
      find.text('8 月 29 日（週六）'),
      findsOneWidget,
      reason: 'the timeline shows the chosen month',
    );

    // 「今天」jumps back to the current month.
    await tester.tap(find.text('今天').hitTestable().first);
    await tester.pump();
    expect(find.text('2026 年 9 月'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('log search stretches over the header and filters', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..selectTab(HomeTab.log);
    await tester.pumpWidget(MishirubeApp(store: store));
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('搜尋紀錄').hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(
      find.bySemanticsLabel('關閉搜尋'),
      findsNothing,
      reason: '× waits until the field has finished stretching',
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('關閉搜尋'), findsOneWidget);
    final field = find.byType(TextField).hitTestable();
    expect(field, findsOneWidget);
    final todayAction = find.widgetWithText(HeaderAction, '今天');
    expect(
      todayAction.hitTestable(),
      findsNothing,
      reason: 'the other actions are pushed out of the row',
    );
    final barSurface = find.ancestor(
      of: field,
      matching: find.byType(ChromeSurface),
    );
    expect(
      tester.widget<ChromeSurface>(barSurface).refracts,
      isTrue,
      reason: 'stays glass once stretched into a field',
    );
    final bar = tester.getRect(barSurface);
    expect(bar.left, AppSpacing.screenGutter, reason: 'reaches the gutter');
    expect(
      tester.getRect(todayAction).right,
      lessThan(0),
      reason: 'pushed right off the screen, not clipped short of it',
    );

    await tester.enterText(field, '午餐');
    await tester.pump();
    expect(find.text('早餐'), findsNothing);
    expect(find.text('午餐'), findsWidgets);

    await tester.enterText(field, '不存在的紀錄');
    await tester.pump();
    expect(find.text('找不到符合「不存在的紀錄」的紀錄。'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('關閉搜尋'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField).hitTestable(), findsNothing);
    expect(todayAction.hitTestable(), findsOneWidget);
    expect(find.text('早餐'), findsWidgets);
    await disposeTree(tester);
  });

  testWidgets('tapping outside search puts the keyboard away', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..selectTab(HomeTab.log);
    await tester.pumpWidget(MishirubeApp(store: store));
    await tester.pump();
    final todayAction = find.widgetWithText(HeaderAction, '今天');
    Future<void> openSearch() async {
      await tester.tap(find.bySemanticsLabel('搜尋紀錄').hitTestable());
      await tester.pumpAndSettle();
    }

    // With a query: keyboard goes, search and its results stay.
    await openSearch();
    final field = find.byType(TextField).hitTestable();
    await tester.enterText(field, '午餐');
    await tester.pump();
    // Blank space beside the large title.
    await tester.tapAt(const Offset(300, 110));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(field, findsOneWidget);
    expect(find.text('晚餐'), findsNothing);

    // Empty: leaving the field closes search too.
    await tester.tap(find.bySemanticsLabel('關閉搜尋'));
    await tester.pumpAndSettle();
    await openSearch();
    // Blank space beside the large title.
    await tester.tapAt(const Offset(300, 110));
    await tester.pumpAndSettle();
    expect(find.byType(TextField).hitTestable(), findsNothing);
    expect(todayAction.hitTestable(), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('turning a module off takes it out of the add menu', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await tester.pumpWidget(MishirubeApp(store: store));
    await tester.pump();
    Finder inMenu(String label) => find.descendant(
      of: find.byKey(quickLogMenuKey),
      matching: find.text(label),
    );
    await tester.tap(find.bySemanticsLabel('新增紀錄'));
    await tester.pumpAndSettle();
    expect(inMenu('睡眠'), findsOneWidget);
    await tester.tapAt(const Offset(20, 120));
    await tester.pumpAndSettle();

    store.toggleModule(AppModule.sleep);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('新增紀錄'));
    await tester.pumpAndSettle();

    expect(
      inMenu('睡眠'),
      findsNothing,
      reason: 'the menu says it lists your modules, so it must',
    );
    await disposeTree(tester);
  });

  testWidgets('the log filters follow the record categories', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..selectTab(HomeTab.log);
    await tester.pumpWidget(MishirubeApp(store: store));
    await tester.pump();

    for (final category in RecordCategory.values) {
      expect(
        find.text(category.label),
        findsWidgets,
        reason:
            '${category.name} has a filter chip without the screen '
            'listing categories itself',
      );
    }
    expect(find.text('全部'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('log chips mark selection with a rim and keep icon colours', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..selectTab(HomeTab.log);
    await tester.pumpWidget(MishirubeApp(store: store));
    await tester.pump();

    Material pillOf(String label) => tester.widget<Material>(
      find
          .descendant(
            of: find.widgetWithText(SelectChip, label),
            matching: find.byType(Material),
          )
          .first,
    );
    Color? iconColorOf(IconData icon) => tester
        .widget<Icon>(
          find.descendant(
            of: find.byType(SelectChip),
            matching: find.byIcon(icon),
          ),
        )
        .color;

    await tester.tap(find.widgetWithText(SelectChip, '訓練'));
    await tester.pump();
    final selected = pillOf('訓練');
    expect(selected.color, AppColors.surfaceRaised, reason: 'no fill');
    expect((selected.shape! as StadiumBorder).side.color, AppColors.training);
    expect((pillOf('飲食').shape! as StadiumBorder).side, BorderSide.none);
    // Icons keep their category colour whether selected or not.
    expect(iconColorOf(Icons.fitness_center), AppColors.training);
    expect(iconColorOf(Icons.restaurant), AppColors.nutrition);
    await disposeTree(tester);
  });

  testWidgets('editing a training template reorders, removes and undoes', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await tester.pumpWidget(MishirubeApp(store: store));

    await _tapText(tester, '下肢 A');
    final planned = [
      for (final exercise in store.routine.exercises) exercise.exercise.name,
    ];
    expect(find.text('上移'), findsNothing, reason: 'browsing cannot reorder');

    await _tapText(tester, '編輯');
    await tester.tap(find.text('下移').first);
    await tester.pump();
    expect(store.routine.exercises.first.exercise.name, planned[1]);

    await tester.tap(find.text('移除').first);
    await tester.pump();
    expect(store.routine.exercises, hasLength(planned.length - 1));
    expect(find.textContaining('已移除'), findsOneWidget);

    await _tapText(tester, '復原');
    expect(
      [for (final exercise in store.routine.exercises) exercise.exercise.name],
      [planned[1], planned[0], ...planned.skip(2)],
      reason: 'undo takes back the removal, not the reorder before it',
    );
    await disposeTree(tester);
  });

  testWidgets('closing the picker with exercises chosen asks first', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await tester.pumpWidget(MishirubeApp(store: store));
    final planned = store.routine.exercises.length;

    await _tapText(tester, '下肢 A');
    await _tapText(tester, '加入動作');
    await tester.enterText(find.byType(TextField), '前蹲');
    await tester.pump();
    // The typed query matches find.text too, so tap the row's card.
    await tester.tap(
      find.ancestor(of: find.text('前蹲'), matching: find.byType(AppCard)).first,
    );
    await tester.pump();
    expect(find.text('加入 1 個動作'), findsOneWidget, reason: 'selection order');

    await tester.tap(find.bySemanticsLabel('關閉'));
    await tester.pump();
    expect(find.text('放棄已選的 1 個動作？'), findsOneWidget);

    await _tapText(tester, '繼續選擇');
    expect(find.text('加入 1 個動作'), findsOneWidget, reason: 'nothing lost');

    await tester.tap(find.bySemanticsLabel('關閉'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '放棄'));
    await tester.pump();
    await tester.pump(_pageTransition);
    expect(store.routine.exercises, hasLength(planned));
    await disposeTree(tester);
  });
}
