import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/features/me/me_screen.dart';
import 'package:mishirube/features/nutrition/daily_nutrition_screen.dart';
import 'package:mishirube/features/nutrition/nutrition_view_model.dart';
import 'package:mishirube/shared/format.dart';
import 'package:mishirube/backend/seed/demo_content.dart';
import 'package:mishirube/app/navigation.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/backend/seed/catalogue.dart';
import 'package:mishirube/backend/engines/food_portion.dart';
import 'package:mishirube/features/journal/note_entry_screen.dart';
import 'package:mishirube/features/journal/sleep_entry_screen.dart';
import 'package:mishirube/features/log/log_screen.dart';
import 'package:mishirube/backend/engines/nutrition_summary.dart';
import 'package:mishirube/features/activity/record_activity_screen.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/features/exercise/exercise_picker_screen.dart';
import 'package:mishirube/features/goal/goal_entry_button.dart';
import 'package:mishirube/features/goal/goal_setup_sheet.dart';
import 'package:mishirube/features/nutrition/food_edit_screen.dart';
import 'package:mishirube/features/nutrition/food_row.dart';
import 'package:mishirube/features/nutrition/food_search_screen.dart';
import 'package:mishirube/features/nutrition/meal_edit_screen.dart';
import 'package:mishirube/features/nutrition/portion_screen.dart';
import 'package:mishirube/features/nutrition/water_card.dart';
import 'package:mishirube/features/sleep/sleep_screen.dart';
import 'package:mishirube/features/trends/trends_view_model.dart';
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
      of: find
          .ancestor(of: find.text(beside).first, matching: find.byType(Row))
          .first,
      matching: find.byType(AppTextField),
    ),
    value,
  );
  await tester.pump();
}

/// Opens [screen] on top of a blank page, so a screen that closes itself
/// when it is done has somewhere to go back to.
Future<void> _openFromHost(
  WidgetTester tester,
  Widget screen,
  AppStore store,
) async {
  const host = Key('host');
  await pumpScreen(tester, const SizedBox(key: host), store: store);
  pushPage(tester.element(find.byKey(host)), screen);
  await tester.pumpAndSettle();
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

    expect(find.text('模組'), findsWidgets);
    await _tapText(tester, '繼續');

    expect(find.text('今天'), findsWidgets);
    await _tapText(tester, '開始訓練');
    expect(find.text('完成這一組'), findsOneWidget);
    expect(find.text('槓鈴深蹲'), findsOneWidget);

    await _tapText(tester, '完成這一組');
    expect(find.text('休息中'), findsOneWidget);
    expect(find.text('個人紀錄'), findsOneWidget);

    await _tapText(tester, '跳過休息');
    expect(store.activeWorkout!.completedSets, 1);

    clock.advance(const Duration(minutes: 30));
    await _tapText(tester, '結束');
    expect(
      find.text('結束這次訓練？'),
      findsOneWidget,
      reason: 'sets are left, so ending is asked, not assumed',
    );
    await _tapText(tester, '結束並儲存');
    expect(find.text('回到今天'), findsOneWidget);
    await _tapText(tester, '太吃力');
    expect(
      store.backend.training.lastFinished()!.workload,
      Workload.tooHard,
      reason: 'the rating is kept with the workout',
    );
    expect(store.lastFinishedWorkout, isNotNull);

    await _tapText(tester, '回到今天');
    expect(find.text('下肢 A 已完成'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('a workout ended early can be given up', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await tester.pumpWidget(MishirubeApp(store: store));
    await _tapText(tester, '開始訓練');
    final id = store.activeWorkout!.id;

    await _tapText(tester, '結束');
    await _tapText(tester, '放棄這次訓練');
    expect(store.activeWorkout, isNull);
    expect(store.lastFinishedWorkout?.id, isNot(id));
    expect(find.text('完成這一組'), findsNothing);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('a rest keeps counting on the workout page and ends there', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final clock = FakeClock();
    final store = AppStore(clock: clock.now, isOnboarded: true);
    await tester.pumpWidget(MishirubeApp(store: store));
    await _tapText(tester, '開始訓練');
    await _tapText(tester, '完成這一組');
    expect(find.text('休息中'), findsOneWidget);
    expect(find.text('2:00'), findsOneWidget, reason: 'a squat rests longer');

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('休息 2:00'), findsOneWidget);

    clock.advance(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('休息 1:00'), findsOneWidget);

    clock.advance(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.textContaining('休息 '), findsNothing);
    expect(store.restEndsAt, isNull);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('ticking a set rests on the page and names a record', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final semantics = tester.ensureSemantics();
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await tester.pumpWidget(MishirubeApp(store: store));
    await _tapText(tester, '開始訓練');

    await tester.tap(find.bySemanticsLabel(RegExp('^第 1 組完成')));
    await tester.pump();
    expect(find.text('休息 2:00'), findsOneWidget);
    expect(find.textContaining('個人紀錄 ·'), findsOneWidget);
    expect(find.text('休息中'), findsNothing, reason: 'no page to leave');
    expect(tester.takeException(), isNull);
    semantics.dispose();
    await disposeTree(tester);
  });

  testWidgets('a set is changed or taken off where it is listed', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final semantics = tester.ensureSemantics();
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await tester.pumpWidget(MishirubeApp(store: store));
    await _tapText(tester, '開始訓練');
    final sets = store.activeWorkout!.currentExercise.sets;
    final count = sets.length;
    final weight = sets.first.weightKg;

    await tester.tap(find.bySemanticsLabel(RegExp('^編輯第 1 組')));
    await tester.pumpAndSettle();
    expect(find.textContaining('每邊'), findsOneWidget, reason: 'a barbell');
    await tester.tap(find.byTooltip('增加 2.5 kg'));
    await tester.tap(find.byTooltip('多 1 次'));
    await tester.tap(find.widgetWithText(SelectChip, '2'));
    await tester.pump();
    await _tapText(tester, '儲存');
    final edited = store.activeWorkout!.currentExercise.sets.first;
    expect(edited.weightKg, weight + 2.5);
    expect(edited.reps, sets.first.reps);
    expect(edited.rir, 2);

    await tester.tap(find.bySemanticsLabel(RegExp('^編輯第 1 組')));
    await tester.pumpAndSettle();
    await _tapText(tester, '刪除這一組');
    expect(store.activeWorkout!.currentExercise.sets, hasLength(count - 1));
    expect(
      store.backend.training.active()!.currentExercise.sets,
      hasLength(count - 1),
      reason: 'kept, not only on screen',
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
    await disposeTree(tester);
  });

  testWidgets('a logged dish splits into its parts and comes back', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.nutrition.logMeal(DemoNutrition.lunch, eatenAt: store.now());
    await tester.pumpWidget(MishirubeApp(store: store));
    pushPage(
      tester.element(find.byType(Navigator).first),
      const DailyNutritionScreen(),
    );
    await tester.pumpAndSettle();

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

  testWidgets('demo data is switched off and on from 我的', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const MeScreen(), store: store);

    await _tapText(tester, '顯示示範資料');
    await tester.pumpAndSettle();
    expect(store.showsDemo, isFalse);
    expect(store.demoRecordCounts, isEmpty);
    expect(
      find.text('顯示示範資料'),
      findsOneWidget,
      reason: 'the switch stays, to bring it back',
    );

    await _tapText(tester, '顯示示範資料');
    await tester.pumpAndSettle();
    expect(store.showsDemo, isTrue);
    expect(store.demoRecordCounts, isNotEmpty);
    await disposeTree(tester);
  });

  testWidgets('pausing and turning off the goal are switches', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..backend.goal.setGoal(3, applyThisWeek: true);
    await pumpScreen(
      tester,
      GoalSetupScreen(overview: store.backend.goal.overview()),
      store: store,
    );
    Finder switchOf(String title) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(NavRow)),
      matching: find.byType(Switch),
    );

    // Backing out of how long to pause leaves the goal running.
    await _tapText(tester, '暫停每週目標');
    expect(find.text('暫停本週'), findsOneWidget);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(store.backend.goal.overview().isPaused, isFalse);

    await _tapText(tester, '暫停每週目標');
    await _tapText(tester, '暫停本週');
    await tester.pumpAndSettle();
    expect(store.backend.goal.overview().isPaused, isTrue);
    expect(tester.widget<Switch>(switchOf('暫停每週目標')).value, isTrue);

    await tester.tap(switchOf('暫停每週目標'));
    await tester.pumpAndSettle();
    expect(
      store.backend.goal.overview().isPaused,
      isFalse,
      reason: 'switched off',
    );

    await tester.tap(switchOf('每週目標'));
    await tester.pumpAndSettle();
    expect(store.backend.goal.isEnabled, isFalse);
    expect(
      find.text('暫停每週目標'),
      findsNothing,
      reason: 'nothing to pause once the goal is off',
    );
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

    expect(store.backend.goal.overview().thisWeek.targetDays, 4);
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
    MuscleFigure figureIn(Backend backend) {
      final trends = TrendsViewModel(backend);
      final figure = trends.muscleFigure;
      trends.dispose();
      return figure;
    }

    expect(figureIn(backend), MuscleFigure.male, reason: 'one has to be first');

    await _tapText(tester, MuscleFigure.female.label);
    await tester.pumpAndSettle();

    expect(
      figureIn(backend),
      MuscleFigure.female,
      reason: 'the choice of drawing is stored, so it survives a restart',
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
      ).backend.nutrition.mealsOn(store.now()).last.kcal,
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
    final row = find
        .ancestor(of: find.text('槓鈴深蹲'), matching: find.byType(NavRow))
        .first;
    expect(
      tester.widget<NavRow>(row).leading,
      isNull,
      reason: 'nothing to select, so no selection box',
    );
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.chevron_right)),
      findsOneWidget,
      reason: 'the row opens the exercise',
    );
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

  testWidgets('a sleep goal is set on the sleep page', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.journal.recordSleep(const Duration(hours: 7));
    await pumpScreen(tester, const SleepScreen(), store: store);

    expect(find.text('未設定'), findsOneWidget);
    await _tapText(tester, '睡眠目標');
    await _tapText(tester, '儲存');
    expect(store.backend.sleep.goal, const Duration(hours: 8));
    expect(find.text('目標 8:00 · 少 1:00'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('a sleep is logged by when it began and ended', (tester) async {
    usePhoneViewport(tester);
    final clock = FakeClock();
    final store = AppStore(clock: clock.now, isOnboarded: true);
    await pumpScreen(tester, const SleepEntryScreen(), store: store);

    await _tapText(tester, '小睡');
    await _tapText(tester, '儲存');
    final nap = store.backend.journal
        .recentSleep(const Duration(days: 1))
        .firstWhere((entry) => entry.kind == SleepKind.nap);
    expect(nap.duration, const Duration(minutes: 30));
    expect(nap.startedAt, clock.now().subtract(const Duration(minutes: 30)));
    await disposeTree(tester);
  });

  testWidgets('a sore muscle is marked before starting', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const RoutineDetailScreen(), store: store);
    final first = store.routine.exercises.first;

    await _tapText(tester, first.exercise.primaryMuscles.first.label);
    expect(find.text('今天少 1 組'), findsWidgets);
    await disposeTree(tester);
  });

  testWidgets('two planned exercises are joined into a superset', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const RoutineDetailScreen(), store: store);

    await _tapText(tester, '編輯');
    await _tapText(tester, '與下一個組成超級組');
    expect(store.routine.exercises.first.joinsNext, isTrue);
    expect(find.widgetWithText(TagChip, '超級組'), findsNWidgets(2));

    await _tapText(tester, '解除超級組');
    expect(store.routine.exercises.first.joinsNext, isFalse);
    expect(find.widgetWithText(TagChip, '超級組'), findsNothing);
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

    await tester.tap(find.bySemanticsLabel('所有訓練模板'));
    await tester.pumpAndSettle();
    expect(find.text(before), findsWidgets);

    await _tapText(tester, '新增訓練模板');
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

    await tester.tap(find.bySemanticsLabel('返回'));
    await tester.pumpAndSettle();
    expect(find.text('放棄已選的 1 個動作？'), findsOneWidget);

    await _tapText(tester, '繼續選擇');
    await tester.pumpAndSettle();
    expect(find.text('加入 1 個動作'), findsOneWidget, reason: 'nothing lost');

    await tester.tap(find.bySemanticsLabel('返回'));
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
    await _openFromHost(tester, const FoodSearchScreen(), store);
    final before = store.todayKcal;

    expect(find.text('沒有食物'), findsOneWidget);

    await _tapText(tester, '新增食物');
    await tester.enterText(find.byType(AppTextField).first, '雞胸肉');
    // The serving amount sits beside the unit chips.
    await tester.enterText(find.byType(AppTextField).at(2), '100');
    await _enterBeside(tester, '熱量', '165');
    await _enterBeside(tester, '蛋白質', '31');
    // Creating and logging is one trip, not two.
    await _tapText(tester, '建立並記錄');
    await tester.pumpAndSettle();
    expect(find.text('加入 100 g'), findsOneWidget, reason: 'opens at a serving');

    // Eating 150 g instead: the servings follow the amount.
    await tester.enterText(find.byType(AppTextField).last, '150');
    await tester.pumpAndSettle();
    await _tapText(tester, '加入 150 g');
    await tester.pumpAndSettle();
    expect(store.todayKcal, before, reason: 'on the plate, not yet logged');

    await tester.tap(find.text('記錄 1 項'));
    await tester.pumpAndSettle();
    expect(store.todayKcal, before + 248, reason: '165 × 1.5, rounded once');
    expect(store.todayMeals.last.proteinGrams, 47);
    expect(store.todayMeals.last.dishes.single.quantityLabel, '150 g');
    await disposeTree(tester);
  });

  testWidgets('a label typed per 100 ml comes to the bottle', (tester) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await _openFromHost(tester, const FoodSearchScreen(), store);

    await _tapText(tester, '新增食物');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(AppTextField).first, '無糖紅茶');
    await tester.enterText(find.byType(AppTextField).at(2), '600');
    await tester.ensureVisible(find.text('ml'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ml'));
    await tester.pumpAndSettle();
    // Bottled drinks print their label per 100 ml.
    await _tapText(tester, '每 100 ml');
    await tester.pumpAndSettle();
    await _enterBeside(tester, '咖啡因', '20');
    await _enterBeside(tester, '糖', '4.5');
    await tester.pump();

    await _tapText(tester, '只建立');
    await tester.pumpAndSettle();
    final saved = store.backend.nutrition.searchFoods('無糖紅茶').single;
    expect(saved.nutrients[Nutrient.caffeine], 120);
    expect(saved.nutrients[Nutrient.sugar], 27, reason: 'the whole label');
    expect(saved.caffeineBasis, CaffeineBasis.per100);
    await disposeTree(tester);
  });

  testWidgets('several foods go on one plate and are logged together', (
    tester,
  ) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    for (final (id, name, kcal) in [('rice', '白飯', 130), ('egg', '蛋', 70)]) {
      final food = store.backend.nutrition.saveFood(
        FoodItem(id: id, name: name, kcal: kcal.toDouble()),
      );
      store.backend.nutrition.logPortion(FoodPortion(food, 1));
    }
    final before = store.todayMeals.length;
    await _openFromHost(tester, const FoodSearchScreen(), store);

    // A list only finds the food; each goes on the plate from its own
    // portion page.
    for (final food in ['白飯', '蛋']) {
      final rows = find.descendant(
        of: find.byType(FoodRow),
        matching: find.text(food),
      );
      // Lazy lists build a row only once it is near the screen. The food
      // can come into view under two sections at once, which
      // dragUntilVisible refuses, so scroll by hand.
      while (rows.evaluate().isEmpty) {
        await tester.drag(find.byType(CustomScrollView).first, _scrollStep);
        await tester.pump();
      }
      final row = rows.first;
      await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
      await tester.pump();
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('加入'));
      await tester.pumpAndSettle();
    }
    expect(find.byIcon(Icons.add), findsNothing, reason: 'no ＋ on a list row');
    expect(find.byTooltip('這一餐 · 2 項 · 200 kcal'), findsOneWidget);

    // Which meal is chosen from the title, for the whole plate.
    await tester.tap(find.bySemanticsLabel(RegExp('這是哪一餐')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('晚餐'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('這一餐 · 晚餐 · 2 項 · 200 kcal'), findsOneWidget);
    await tester.tap(find.text('記錄 2 項'));
    await tester.pumpAndSettle();

    final plate = store.todayMeals.skip(before).toList();
    expect(plate.map((m) => m.name), ['白飯', '蛋']);
    expect(
      plate.map((m) => m.mealType).toSet(),
      {MealType.dinner},
      reason: 'the meal chosen on the page applies to the whole plate',
    );
    await disposeTree(tester);
  });

  testWidgets('every nutrient is on the form without asking', (
    tester,
  ) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const FoodEditScreen(), store: store);

    await tester.dragUntilVisible(
      find.text('鈣'),
      find.byType(CustomScrollView).hitTestable().first,
      _scrollStep,
    );
    expect(find.text('鈣'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('a habitual meal label is offered, not chosen', (tester) async {
    final clock = FakeClock()..current = DateTime(2026, 9, 17, 15);
    final store = AppStore(clock: clock.now, isOnboarded: true);
    for (var day = 0; day < 2; day++) {
      store.backend.nutrition.logPortion(
        FoodPortion(FoodItem(id: 'rice$day', name: '便當', kcal: 700), 1),
        mealType: MealType.lunch,
      );
      clock.advance(const Duration(days: 1));
    }
    await pumpScreen(tester, const FoodSearchScreen(), store: store);

    expect(find.textContaining('常用：午餐'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('目前不指定')),
      findsOneWidget,
      reason: 'nothing is picked on the user\'s behalf',
    );

    await tester.tap(find.text('套用'));
    await tester.pump();
    expect(
      find.text('套用'),
      findsNothing,
      reason: 'taken, so no longer offered',
    );
    expect(find.bySemanticsLabel(RegExp('目前午餐')), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('a night in the log opens its sleep page', (tester) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.journal.recordSleep(const Duration(hours: 7), score: 4);
    await pumpScreen(tester, const LogScreen(), store: store);

    await _tapText(tester, '睡眠 7:00');
    await tester.pumpAndSettle();

    expect(find.byType(SleepScreen), findsOneWidget);
    expect(
      find.textContaining('紀錄的睡眠'),
      findsOneWidget,
      reason: 'typed in, not measured',
    );
    expect(find.text('睡眠階段'), findsNothing, reason: 'no stages to show');
    expect(find.text('品質 4 / 5'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('a weight in the log opens, corrects and deletes with undo', (
    tester,
  ) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.journal.recordWeight(81.2);
    await pumpScreen(tester, const LogScreen(), store: store);

    await _tapText(tester, '體重 81.2 kg');
    await tester.pumpAndSettle();
    expect(find.text('手動輸入'), findsOneWidget, reason: 'where it came from');

    await _tapText(tester, '編輯');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '80.4');
    await _tapText(tester, '儲存');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('80.4', findRichText: true),
      findsWidgets,
      reason: 'the detail shows the corrected value',
    );

    await _tapText(tester, '刪除這筆紀錄');
    // Not pumpAndSettle: that would sit out the toast and its undo.
    await tester.pump();
    await tester.pump(_pageTransition);
    expect(find.text('體重 80.4 kg'), findsNothing, reason: 'gone from the log');

    await tester.tap(find.text('復原'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('體重 80.4 kg'), findsOneWidget, reason: 'and back');
    await disposeTree(tester);
  });

  testWidgets('a note written today shows up in the log', (tester) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const LogScreen(), store: store);
    pushPage(tester.element(find.byType(LogScreen)), const NoteEntryScreen());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '晚上聚餐，吃得比平常多');
    await tester.pump();
    await _tapText(tester, '儲存');
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('晚上聚餐，吃得比平常多'),
      find.byType(CustomScrollView).first,
      _scrollStep,
    );
    expect(find.text('晚上聚餐，吃得比平常多'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('a chain is one row, and naming it opens its menu', (
    tester,
  ) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    for (final food in parseCatalogue({
      'brand': '星巴克',
      'market': 'tw',
      'sourceUrl': 'https://example.com',
      'checkedAt': '2026-09-21',
      'valueType': 'declared',
      'drinks': [
        for (final (id, name) in [('latte', '那堤'), ('mocha', '摩卡')])
          {
            'id': id,
            'name': name,
            'sizes': [
              {'name': 'Tall', 'millilitres': 350, 'caffeineMg': 150},
            ],
          },
      ],
    })) {
      store.backend.storage.foods.save(food, source: ChangeSource.catalogue);
    }
    await _openFromHost(tester, const FoodSearchScreen(), store);

    expect(
      find.text('連鎖品牌'),
      findsNothing,
      reason: '「全部」is for what the user eats; chains have their scope',
    );
    // The scopes scroll sideways, like the log's categories.
    await tester.scrollUntilVisible(
      find.text('品牌'),
      100,
      scrollable: find.descendant(
        of: find.byWidgetPredicate((widget) => widget is FilterChipBar),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('品牌'));
    await tester.pump();
    expect(find.text('星巴克'), findsOneWidget);
    expect(
      find.text('那堤'),
      findsNothing,
      reason: 'the chain is one row, not every drink on its menu',
    );

    await tester.scrollUntilVisible(
      find.text('全部'),
      -100,
      scrollable: find.descendant(
        of: find.byWidgetPredicate((widget) => widget is FilterChipBar),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('全部'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '星巴克');
    await tester.pump();
    await tester.tap(find.text('星巴克 · 查看完整菜單'));
    await tester.pumpAndSettle();
    expect(find.text('那堤'), findsOneWidget);
    expect(find.text('摩卡'), findsOneWidget);

    // Taking a cup off the plate from the plate's own page empties the
    // menu's plate bar as well, not only the page that owns the plate.
    await tester.tap(find.text('那堤'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tall'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('加入'));
    await tester.pumpAndSettle();
    expect(find.text('記錄 1 項'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();

    // Sliding a row only uncovers 移除; nothing goes until it is tapped.
    await tester.drag(find.text('星巴克 那堤 Tall'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('記錄 1 項'), findsOneWidget);
    await tester.tap(find.text('移除'));
    // Not pumpAndSettle: the undo countdown would run the toast out.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('繼續選擇'),
      findsOneWidget,
      reason: 'emptying the plate is not the same as leaving it',
    );
    await tester.tap(find.text('復原'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('記錄 1 項'), findsOneWidget, reason: 'undo puts it back');

    // The same without the gesture: 編輯 shows a remove button per row.
    await tester.tap(find.text('編輯'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('移除「星巴克 那堤 Tall」'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('繼續選擇'));
    await tester.pumpAndSettle();
    expect(find.text('摩卡'), findsOneWidget, reason: 'back on the menu');
    expect(find.text('記錄 1 項'), findsNothing);
    expect(find.byIcon(Icons.receipt_long_outlined), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('the food library keeps own foods and browses brands', (
    tester,
  ) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.nutrition.saveFood(
      FoodItem(
        id: store.backend.nutrition.newFoodId(),
        name: '自煮雞胸',
        kcal: 165,
      ),
    );
    for (final food in parseCatalogue({
      'brand': '星巴克',
      'market': 'tw',
      'sourceUrl': 'https://example.com',
      'checkedAt': '2026-09-21',
      'valueType': 'declared',
      'drinks': [
        {
          'id': 'latte',
          'name': '那堤',
          'sizes': [
            {'name': 'Tall', 'millilitres': 350, 'caffeineMg': 150},
          ],
        },
      ],
    })) {
      store.backend.storage.foods.save(food, source: ChangeSource.catalogue);
    }
    await pumpScreen(tester, const MeScreen(), store: store);

    await _tapText(tester, '食物庫');
    await tester.pumpAndSettle();
    expect(find.text('自煮雞胸'), findsOneWidget, reason: 'own foods listed');
    expect(find.text('星巴克'), findsOneWidget, reason: 'brands listed');

    // Searching narrows both.
    await tester.enterText(find.byType(TextField), '雞胸');
    await tester.pump();
    expect(find.text('自煮雞胸'), findsOneWidget);
    expect(find.text('星巴克'), findsNothing);

    // An own food opens to be corrected.
    await tester.tap(find.text('自煮雞胸'));
    await tester.pumpAndSettle();
    expect(find.byType(FoodEditScreen), findsOneWidget);
    await tester.tap(find.byTooltip('返回').last);
    await tester.pumpAndSettle();

    // A brand opens its menu, to browse.
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.text('星巴克'));
    await tester.pumpAndSettle();
    expect(find.text('那堤'), findsOneWidget);

    // A drink opens on its figures, after its cup, with nothing to add to.
    await tester.tap(find.text('那堤'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tall'));
    await tester.pumpAndSettle();
    expect(find.byType(PortionScreen), findsOneWidget);
    expect(find.textContaining('加入'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('what is already logged today is one tap away', (tester) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final day = store.todaySummary;
    await pumpScreen(tester, const FoodSearchScreen(), store: store);

    final row = find.text('${day.mealCount} 餐 · ${formatKcal(day.kcal)} kcal');
    expect(
      row,
      findsOneWidget,
      reason: 'the page is opened from ＋, not from the day',
    );
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(DailyNutritionScreen), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('the water card logs a glass and keeps water apart', (
    tester,
  ) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    // A coffee with a volume: a drink, but not water.
    store.backend.nutrition.logPortion(
      FoodPortion(
        const FoodItem(
          id: 'latte',
          name: '拿鐵',
          kind: ConsumptionKind.beverage,
          servingUnit: ServingUnit.millilitre,
          servingAmount: 350,
        ),
        1,
      ),
    );
    await pumpScreen(tester, const FoodSearchScreen(), store: store);
    final nutrition = NutritionViewModel(store.backend);
    addTearDown(nutrition.dispose);
    final glass = nutrition.glassMillilitres;

    expect(nutrition.todayWater.millilitres, 0, reason: 'coffee is not water');
    await tester.tap(find.text('＋ $glass mL'));
    await tester.pump();

    expect(nutrition.todayWater.millilitres, glass);
    expect(nutrition.todayWater.times, 1);
    expect(
      find.textContaining('飲品總量 ${glass + 350} mL'),
      findsOneWidget,
      reason: 'other drinks are counted on a line of their own',
    );
    expect(
      find.descendant(
        of: find.byType(WaterCard),
        matching: find.textContaining('目標'),
      ),
      findsNothing,
      reason: 'no daily amount the app cannot vouch for',
    );

    await tester.tap(find.text('復原'));
    await tester.pump();
    expect(nutrition.todayWater.millilitres, 0);
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

    await _tapText(tester, '新增食物');
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

  testWidgets('a quick record never joins the list', (tester) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const FoodSearchScreen(), store: store);
    final before = store.todayKcal;
    final saved = store.backend.nutrition.searchFoods('').length;

    await _tapText(tester, '快速記錄');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(AppTextField).first, '同事帶的蛋糕');
    await _enterBeside(tester, '熱量', '320');
    await _tapText(tester, '記錄');
    await tester.pumpAndSettle();

    expect(store.todayKcal, before + 320);
    expect(
      store.backend.nutrition.searchFoods(''),
      hasLength(saved),
      reason: 'a one-off is logged without being saved for next time',
    );
    await disposeTree(tester);
  });

  testWidgets('a quick record can also keep the food', (tester) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const FoodSearchScreen(), store: store);
    final before = store.todayKcal;

    await _tapText(tester, '快速記錄');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(AppTextField).first, '公司樓下便當');
    await _tapText(tester, '存入食物庫');
    await _enterBeside(tester, '熱量', '650');
    await _tapText(tester, '記錄');
    await tester.pumpAndSettle();

    expect(store.todayKcal, before + 650);
    expect(
      store.backend.nutrition.searchFoods('便當').map((food) => food.name),
      contains('公司樓下便當'),
      reason: 'switched on, it is there to pick next time',
    );
    await disposeTree(tester);
  });

  testWidgets('a glass of water is one tap and one kind of record', (
    tester,
  ) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const FoodSearchScreen(), store: store);
    final before = summariseFluid(store.todayMeals).millilitres;

    await _tapText(tester, '＋ 250 mL');
    await tester.pumpAndSettle();

    expect(summariseFluid(store.todayMeals).millilitres, before + 250);
    expect(
      summariseDay(store.todayMeals).mealCount,
      summariseDay(store.todayMeals.where((m) => m.name != '水')).mealCount,
      reason: 'a glass of water is not a meal',
    );
    await disposeTree(tester);
  });

  testWidgets('a meal with no figures edits without showing null', (
    tester,
  ) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    const unknown = FoodItem(
      id: 'stall',
      name: '路邊攤炒麵',
      kind: ConsumptionKind.food,
    );
    final logged = store.backend.nutrition.logPortion(
      const FoodPortion(unknown, 1),
    );
    await pumpScreen(tester, MealEditScreen(meal: logged), store: store);

    expect(
      find.text('null'),
      findsNothing,
      reason: 'an empty field is a figure nobody wrote down',
    );

    // Saving it back keeps it unknown rather than inventing a zero.
    await _tapText(tester, '儲存');
    await tester.pumpAndSettle();
    expect(store.todayMeals.last.kcal, isNull);
    await disposeTree(tester);
  });
}
