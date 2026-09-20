import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/features/activity/record_activity_screen.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/features/exercise/exercise_picker_screen.dart';
import 'package:mishirube/features/goal/goal_entry_button.dart';
import 'package:mishirube/features/nutrition/food_edit_screen.dart';
import 'package:mishirube/features/nutrition/food_search_screen.dart';
import 'package:mishirube/features/nutrition/meal_edit_screen.dart';
import 'package:mishirube/features/training/routine_detail_screen.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/shell/bottom_chrome/quick_log_menu.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import 'support/harness.dart';

const _pageTransition = Duration(milliseconds: 600);

const _scrollStep = Offset(0, -200);

/// Types [value] into the field on the same row as the label [beside],
/// scrolling it into view first. Finding fields by position breaks every
/// time the form grows a row.
Future<void> _enterBeside(
  WidgetTester tester,
  String beside,
  String value,
) async {
  if (find.text(beside).evaluate().isEmpty) {
    await tester.dragUntilVisible(
      find.text(beside),
      find.byType(CustomScrollView).hitTestable().first,
      _scrollStep,
    );
  }
  await Scrollable.ensureVisible(
    tester.element(find.text(beside).first),
    alignment: 0.5,
  );
  await tester.pump();
  await tester.enterText(
    find.descendant(
      of: find.ancestor(
        of: find.text(beside).first,
        matching: find.byType(Row),
      ).first,
      matching: find.byType(AppTextField),
    ),
    value,
  );
  await tester.pump();
}

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

  testWidgets('logging exercise from the add menu reaches the log', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await tester.pumpWidget(MishirubeApp(store: store));
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('新增紀錄'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(quickLogMenuKey),
        matching: find.text('運動'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('運動類型'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('健走').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('45 分'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();

    store.selectTab(HomeTab.log);
    await tester.pumpAndSettle();
    expect(find.text('健走'), findsWidgets);
    expect(find.text('45 分'), findsWidgets);
    await disposeTree(tester);
  });

  testWidgets('timing a session keeps the rest of the app reachable', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final clock = FakeClock();
    final store = AppStore(clock: clock.now, isOnboarded: true);
    await tester.pumpWidget(MishirubeApp(store: store));
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('新增紀錄'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(quickLogMenuKey),
        matching: find.text('運動'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('現在開始計時'));
    await tester.pumpAndSettle();

    clock.advance(const Duration(minutes: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('3:00'), findsWidgets, reason: 'the clock is running');

    // Back on the shell, the accessory says what is running.
    await tester.tap(find.bySemanticsLabel('返回'));
    await tester.pumpAndSettle();
    // The form opened on the type used last, so that is what is running.
    expect(find.textContaining('騎自行車進行中'), findsOneWidget);

    // Training must not quietly take over the running session.
    store.selectTab(HomeTab.today);
    await tester.pumpAndSettle();
    await _tapText(tester, '開始訓練');
    await tester.pump();
    await tester.pump(_pageTransition);
    expect(store.activeSession, isA<ActiveActivity>());
    expect(find.textContaining('先結束運動'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('setting a weekly goal puts the ring in the toolbar', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await tester.pumpWidget(MishirubeApp(store: store));
    await tester.pump();
    expect(
      find.byType(GoalEntryButton).hitTestable(),
      findsNothing,
      reason: 'nothing is set up, so nothing is offered',
    );

    store.selectTab(HomeTab.me);
    await tester.pumpAndSettle();
    await _tapText(tester, '每週目標');
    await tester.pumpAndSettle();
    await _tapText(tester, '設定每週目標');
    await tester.pumpAndSettle();

    await tester.tap(find.text('4 天'));
    await tester.pump();
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();

    expect(store.goalOverview.thisWeek.targetDays, 4);
    expect(find.textContaining('本週'), findsWidgets);

    // Back out of the goal page to the shell.
    await tester.tap(find.bySemanticsLabel('返回'));
    await tester.pumpAndSettle();
    store.selectTab(HomeTab.today);
    await tester.pumpAndSettle();
    expect(
      find.byType(GoalEntryButton).hitTestable(),
      findsOneWidget,
      reason: 'the toolbar shows the week once there is a goal',
    );
    await disposeTree(tester);
  });

  testWidgets('the muscle map can be drawn on either body', (tester) async {
    usePhoneViewport(tester);
    final backend = Backend.inMemory(clock: FakeClock().now);
    addTearDown(backend.close);
    final store = AppStore(
      clock: FakeClock().now,
      isOnboarded: true,
      backend: backend,
    )..selectTab(HomeTab.trends);
    await tester.pumpWidget(MishirubeApp(store: store));
    await tester.pumpAndSettle();
    expect(
      store.muscleFigure,
      MuscleFigure.male,
      reason: 'one has to be first',
    );

    await _tapText(tester, MuscleFigure.female.label);
    await tester.pumpAndSettle();

    expect(store.muscleFigure, MuscleFigure.female);
    expect(
      AppStore(clock: FakeClock().now, backend: backend).muscleFigure,
      MuscleFigure.female,
      reason: 'the choice of drawing survives a restart',
    );
    await disposeTree(tester);
  });

  testWidgets('a weight change is not painted as good or bad news', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..selectTab(HomeTab.trends);
    await tester.pumpWidget(MishirubeApp(store: store));
    await tester.pumpAndSettle();

    final delta = find.textContaining(RegExp('^[−+]'));
    expect(delta, findsWidgets, reason: 'the demo weight is trending');
    for (final text in tester.widgetList<Text>(delta)) {
      expect(
        text.style?.color,
        isNot(isIn([AppColors.training, AppColors.destructive])),
        reason: 'a week of fluctuation is not a verdict on the user',
      );
    }
    await disposeTree(tester);
  });

  testWidgets('correcting a meal takes the estimate mark off it', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..confirmLunch();
    final before = store.todayMeals.last;
    await pumpScreen(tester, MealEditScreen(meal: before), store: store);

    await tester.enterText(find.byType(TextField).at(1), '700');
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();

    final after = store.todayMeals.last;
    expect(after.kcal, 700, reason: 'the number the user typed');
    expect(after.isEstimated, isFalse, reason: 'confirmed, not guessed');
    expect(after.qualityTag, '已確認');
    expect(
      AppStore(
        clock: FakeClock().now,
        backend: store.backend,
      ).mealsOn(store.now()).last.kcal,
      700,
      reason: 'and it is stored, not only shown',
    );
    await disposeTree(tester);
  });

  testWidgets('browsing the catalogue picks nothing', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(
      tester,
      const ExercisePickerScreen(purpose: PickerPurpose.browse),
      store: store,
    );

    await tester.enterText(find.byType(TextField), '深蹲');
    await tester.pump();
    await tester.tap(
      find
          .ancestor(of: find.text('槓鈴深蹲'), matching: find.byType(AppCard))
          .first,
    );
    await tester.pump();
    await tester.pump(_pageTransition);

    // The tap opened the exercise instead of selecting it, so there is
    // nothing to confirm.
    expect(find.text('加入 1 個動作'), findsNothing);
    expect(find.text('加入這個動作'), findsNothing, reason: 'nothing to add to');
    await disposeTree(tester);
  });

  testWidgets('a suggestion says why, and only changes the plan if taken', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const RoutineDetailScreen(), store: store);

    await _tapText(tester, '下次的建議');
    final (planned, suggestion) = store.progressionSuggestions.firstWhere(
      (entry) => entry.$2.changesWeight,
    );
    expect(find.text(suggestion.reason), findsOneWidget, reason: 'the why');

    // Turning one down leaves the plan alone.
    await _tapText(tester, '維持原本');
    await tester.pumpAndSettle();
    expect(
      store.routine.exercises
          .firstWhere((item) => item.exercise.id == planned.exercise.id)
          .targetWeightKg,
      planned.targetWeightKg,
    );

    final next = store.progressionSuggestions.firstWhere(
      (entry) => entry.$2.changesWeight,
    );
    await _tapText(tester, '套用');
    await tester.pumpAndSettle();
    expect(
      store.routine.exercises
          .firstWhere((item) => item.exercise.id == next.$1.exercise.id)
          .targetWeightKg,
      next.$2.targetWeightKg,
    );
    await disposeTree(tester);
  });

  testWidgets('a new training template becomes the one to train next', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const RoutineDetailScreen(), store: store);
    final before = store.routine.name;

    await tester.tap(find.bySemanticsLabel('所有訓練'));
    await tester.pumpAndSettle();
    expect(find.text(before), findsWidgets);

    await _tapText(tester, '新增訓練');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '上肢 B');
    await tester.tap(find.text('建立'));
    await tester.pumpAndSettle();

    expect(store.routine.name, '上肢 B');
    expect(
      find.text('上肢 B'),
      findsWidgets,
      reason: 'the detail screen follows the choice',
    );
    expect(store.routines.map((routine) => routine.name), contains(before));
    await disposeTree(tester);
  });

  testWidgets('stopping a session asks in the app own dialog', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..startActivity(ActivityTypes.running);
    await tester.pumpWidget(MishirubeApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('結束跑步'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsOneWidget);
    expect(
      find.byType(AlertDialog),
      findsNothing,
      reason: 'dialogs wear the app chrome, not Material default',
    );
    expect(find.text('結束這次跑步？'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('放棄這次運動')).style?.color,
      AppColors.destructive,
      reason: 'losing the session for good is not an amber caution',
    );

    await tester.tap(find.text('繼續跑步'));
    await tester.pumpAndSettle();
    expect(store.activeSession, isA<ActiveActivity>());
    await disposeTree(tester);
  });

  testWidgets('the form asks only what the type can measure', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const RecordActivityScreen(), store: store);

    await tester.tap(find.text('運動類型'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('健行').last);
    await tester.pumpAndSettle();
    expect(find.text('距離（選填）'), findsOneWidget);
    expect(find.text('爬升（選填）'), findsOneWidget);

    await tester.tap(find.text('運動類型'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('瑜伽').last);
    await tester.pumpAndSettle();
    expect(find.text('距離（選填）'), findsNothing);
    expect(
      find.text('爬升（選填）'),
      findsNothing,
      reason: 'the form follows the type, not a list of sports',
    );
    await disposeTree(tester);
  });

  testWidgets('a logged session can be corrected and taken back', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..selectTab(HomeTab.log);
    await tester.pumpWidget(MishirubeApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('騎自行車').first);
    await tester.pumpAndSettle();
    expect(find.text('配速 /km'), findsOneWidget);

    await tester.tap(find.text('編輯內容'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('60 分'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();
    expect(find.text('60'), findsWidgets, reason: 'the detail shows the fix');

    await tester.tap(find.text('刪除這筆紀錄'));
    await tester.pump();
    await tester.pump(_pageTransition);
    expect(find.text('騎自行車'), findsNothing);

    await tester.tap(find.text('復原'));
    await tester.pump();
    expect(find.text('騎自行車'), findsWidgets);
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
    await tester.pumpAndSettle();
    expect(find.text('放棄已選的 1 個動作？'), findsOneWidget);

    await _tapText(tester, '繼續選擇');
    await tester.pumpAndSettle();
    expect(find.text('加入 1 個動作'), findsOneWidget, reason: 'nothing lost');

    await tester.tap(find.bySemanticsLabel('關閉'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放棄已選的動作'));
    await tester.pump();
    await tester.pump(_pageTransition);
    expect(store.routine.exercises, hasLength(planned));
    await disposeTree(tester);
  });

  testWidgets('a food is saved once, then logged at a different portion', (
    tester,
  ) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const FoodSearchScreen(), store: store);
    final before = store.todayKcal;

    expect(find.text('還沒有存過東西'), findsOneWidget);

    await _tapText(tester, '新增食物或飲品');
    await tester.enterText(find.byType(AppTextField).first, '雞胸肉');
    // The serving amount sits beside the unit chips.
    await tester.enterText(find.byType(AppTextField).at(2), '100');
    await _enterBeside(tester, '熱量', '165');
    await _enterBeside(tester, '蛋白質', '31');
    // Creating and logging is one trip, not two.
    await _tapText(tester, '建立並記錄');
    await tester.pumpAndSettle();
    expect(find.text('記錄 100 g'), findsOneWidget, reason: 'opens at a serving');

    // Eating 150 g instead: the servings follow the amount.
    await tester.enterText(find.byType(AppTextField).last, '150');
    await tester.pumpAndSettle();
    await _tapText(tester, '記錄 150 g');
    await tester.pumpAndSettle();

    expect(store.todayKcal, before + 248, reason: '165 × 1.5, rounded once');
    expect(store.todayMeals.last.proteinGrams, 47);
    expect(store.todayMeals.last.dishes.single.quantityLabel, '150 g');
    await disposeTree(tester);
  });

  testWidgets('leaving any field puts the keyboard away', (tester) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const FoodEditScreen(), store: store);

    await tester.tap(find.byType(AppTextField).first);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);

    // A tap on the page, outside every field.
    await tester.tapAt(const Offset(200, 120));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    await disposeTree(tester);
  });

  testWidgets('creating without logging leaves the day alone', (tester) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const FoodSearchScreen(), store: store);
    final before = store.todayMeals.length;

    await _tapText(tester, '新增食物或飲品');
    await tester.enterText(find.byType(AppTextField).first, '燕麥');
    await tester.enterText(find.byType(AppTextField).at(2), '40');
    await _enterBeside(tester, '熱量', '150');
    await _tapText(tester, '只建立');
    await tester.pumpAndSettle();

    expect(find.text('燕麥'), findsOneWidget, reason: 'saved to the list');
    expect(
      store.todayMeals,
      hasLength(before),
      reason: 'saving a food is not eating it',
    );
    await disposeTree(tester);
  });
}
