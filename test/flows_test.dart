import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodCall, MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/features/me/ai_settings_screen.dart';
import 'package:mishirube/features/me/me_screen.dart';
import 'package:mishirube/features/me/references_screen.dart';
import 'package:mishirube/features/nutrition/daily_nutrition_screen.dart';
import 'package:mishirube/features/nutrition/meal_change_preview_screen.dart';
import 'package:mishirube/features/nutrition/meal_detail_screen.dart';
import 'package:mishirube/features/nutrition/meal_group_screen.dart';
import 'package:mishirube/features/nutrition/nutrition_target_screen.dart';
import 'package:mishirube/features/nutrition/nutrition_view_model.dart';
import 'package:mishirube/backend/seed/demo_content.dart';
import 'package:mishirube/app/navigation.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/features/journal/measurement_entry_screen.dart';
import 'package:mishirube/backend/ai/secret_store.dart';
import 'package:mishirube/backend/ai/label_reader.dart';
import 'package:mishirube/backend/application/ai_service.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/backend/seed/catalogue.dart';
import 'package:mishirube/backend/engines/food_portion.dart';
import 'package:mishirube/features/body/body_screen.dart';
import 'package:mishirube/features/journal/body_reading_entry_screen.dart';
import 'package:mishirube/features/journal/journal_detail_screen.dart';
import 'package:mishirube/features/journal/note_entry_screen.dart';
import 'package:mishirube/features/journal/sleep_entry_screen.dart';
import 'package:mishirube/features/log/log_screen.dart';
import 'package:mishirube/backend/engines/nutrition_summary.dart';
import 'package:mishirube/backend/engines/training_metrics.dart';
import 'package:mishirube/features/activity/record_activity_screen.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/features/exercise/exercise_picker_screen.dart';
import 'package:mishirube/features/goal/goal_entry_button.dart';
import 'package:mishirube/features/goal/goal_setup_sheet.dart';
import 'package:mishirube/features/nutrition/food_edit_screen.dart';
import 'package:mishirube/features/nutrition/food_row.dart';
import 'package:mishirube/features/nutrition/food_search_screen.dart';
import 'package:mishirube/features/nutrition/recent_meal_row.dart';
import 'package:mishirube/features/nutrition/portion_screen.dart';
import 'package:mishirube/features/water/water_card.dart';
import 'package:mishirube/features/water/water_screen.dart';
import 'package:mishirube/features/sleep/sleep_screen.dart';
import 'package:mishirube/features/trends/trend_detail_screen.dart';
import 'package:mishirube/backend/engines/trend_findings.dart';
import 'package:mishirube/features/today/today_screen.dart';
import 'package:mishirube/features/trends/muscle_trends_screen.dart';
import 'package:mishirube/features/trends/trends_view_model.dart';
import 'package:mishirube/features/training/substitute_exercise_screen.dart';
import 'package:mishirube/features/training/workout_summary_screen.dart';
import 'package:mishirube/features/training/active_workout_screen.dart';
import 'package:mishirube/features/training/training_screen.dart';
import 'package:mishirube/features/training/routine_detail_screen.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/shell/bottom_chrome/quick_log_menu.dart';
import 'package:mishirube/shared/format.dart';
import 'package:mishirube/shared/widgets/widgets.dart';
import 'package:mishirube/l10n/l10n.dart';

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

/// The page's own list, not a sideways row such as the week strip.
final _pageScroll = find
    .byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    )
    .first;

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

/// Opens a 課表 the way the user does: ＋, 訓練, then the 課表.
Future<void> _openRoutine(WidgetTester tester, [String name = '下肢 A']) async {
  await tester.tap(find.bySemanticsLabel('新增紀錄'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byKey(quickLogMenuKey), matching: find.text('訓練')),
  );
  await tester.pumpAndSettle();
  await _tapText(tester, name);
}

/// Starts a workout from a 課表, opened as the user opens one.
Future<void> _startFromRoutine(WidgetTester tester) async {
  await _openRoutine(tester);
  await _tapText(tester, '開始訓練');
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
    await _startFromRoutine(tester);
    expect(
      find.text('開始運動'),
      findsOneWidget,
      reason: 'ready to look over, not yet under way',
    );
    expect(find.text('槓鈴深蹲'), findsOneWidget);
    await _tapText(tester, '開始運動');
    expect(find.text('完成訓練'), findsOneWidget);

    final semantics = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel(RegExp('^第 1 組完成')).first);
    await tester.pump();
    expect(find.textContaining('個人紀錄 ·'), findsOneWidget);
    expect(store.restEndsAt, isNotNull, reason: 'the rest starts in place');

    expect(
      find.text('跳過休息'),
      findsOneWidget,
      reason: 'the rest shows its choices',
    );
    final endsAt = store.restEndsAt!;
    await _tapText(tester, '+30 秒');
    expect(store.restEndsAt, endsAt.add(const Duration(seconds: 30)));
    await _tapText(tester, '跳過休息');
    semantics.dispose();
    expect(store.restEndsAt, isNull);
    expect(store.activeWorkout!.completedSets, 1);

    clock.advance(const Duration(minutes: 30));
    await _tapText(tester, '結束');
    expect(
      find.text('結束這次訓練？'),
      findsOneWidget,
      reason: 'sets are left, so ending is asked, not assumed',
    );
    await _tapText(tester, '結束並儲存');
    expect(find.text('這次的負荷'), findsOneWidget, reason: 'the summary');
    await _tapText(tester, '太吃力');
    expect(
      store.backend.training.lastFinished()!.workload,
      Workload.tooHard,
      reason: 'the rating is kept with the workout',
    );
    expect(store.lastFinishedWorkout, isNotNull);

    // Straight back to Today: the training page it was started from
    // closed when the workout opened.
    await tester.tap(find.bySemanticsLabel('返回').last);
    await tester.pumpAndSettle();
    expect(find.text('下肢 A 已完成'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('a workout is collapsed to where it was started from, and '
      'paused from its bar', (tester) async {
    usePhoneViewport(tester);
    final clock = FakeClock();
    final store = AppStore(clock: clock.now, isOnboarded: true);
    await tester.pumpWidget(MishirubeApp(store: store));
    await _startFromRoutine(tester);
    expect(find.text('暫停'), findsNothing, reason: 'nothing runs yet');
    await _tapText(tester, '開始運動');
    clock.advance(const Duration(minutes: 5));

    await _tapText(tester, '暫停');
    expect(store.activeWorkout!.isPaused, isTrue);
    expect(find.textContaining('已暫停'), findsWidgets);
    await _tapText(tester, '繼續');
    expect(store.activeWorkout!.isPaused, isFalse);

    await tester.tap(find.bySemanticsLabel('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(ActiveWorkoutScreen), findsNothing);
    expect(
      find.byType(TrainingScreen),
      findsNothing,
      reason: 'not back to the page the workout was picked on',
    );
    expect(store.activeWorkout, isNotNull, reason: 'still under way');
    await disposeTree(tester);
  });

  testWidgets('a workout ended early can be given up', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await tester.pumpWidget(MishirubeApp(store: store));
    await _startFromRoutine(tester);
    final id = store.activeWorkout!.id;

    await _tapText(tester, '開始運動');
    await _tapText(tester, '結束');
    await _tapText(tester, '放棄這次訓練');
    expect(store.activeWorkout, isNull);
    expect(store.lastFinishedWorkout?.id, isNot(id));
    expect(find.text('完成訓練'), findsNothing);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('a rest counts down at the foot and ends there', (tester) async {
    usePhoneViewport(tester);
    final semantics = tester.ensureSemantics();
    final clock = FakeClock();
    final store = AppStore(clock: clock.now, isOnboarded: true);
    await tester.pumpWidget(MishirubeApp(store: store));
    await _startFromRoutine(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('^第 1 組完成')).first);
    await tester.pump();
    expect(find.text('2:00'), findsOneWidget, reason: 'a squat rests longer');

    clock.advance(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('1:00'),
      findsWidgets,
      reason: 'the rest, beside the time so far',
    );

    clock.advance(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(store.restEndsAt, isNull);
    expect(tester.takeException(), isNull);
    semantics.dispose();
    await disposeTree(tester);
  });

  testWidgets('the system is told of a rest and of a set timed, and not of '
      'a rest that ran out', (tester) async {
    usePhoneViewport(tester);
    final semantics = tester.ensureSemantics();
    final calls = <MethodCall>[];
    const channel = MethodChannel('mishirube/rest_notice');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final clock = FakeClock();
    final store = AppStore(clock: clock.now, isOnboarded: true);
    await tester.pumpWidget(MishirubeApp(store: store));
    expect(calls.map((call) => call.method), [
      'cancel',
      'cancelSet',
    ], reason: 'the first look clears what an earlier run left');

    await _startFromRoutine(tester);
    await _tapText(tester, '開始運動');
    calls.clear();
    await tester.tap(find.bySemanticsLabel(RegExp('^第 1 組完成')).first);
    await tester.pump();
    final schedule = calls.singleWhere((call) => call.method == 'schedule');
    expect(
      (schedule.arguments as Map)['endsAt'],
      store.restEndsAt!.millisecondsSinceEpoch.toDouble(),
    );
    expect((schedule.arguments as Map)['body'], contains('槓鈴深蹲 · '));
    expect((schedule.arguments as Map)['skipLabel'], '跳過休息');

    calls.clear();
    clock.advance(store.restLength);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(calls.map((call) => call.method), contains('ended'));
    expect(
      calls.map((call) => call.method),
      isNot(contains('cancel')),
      reason: 'its alert may be on the lock screen already',
    );

    calls.clear();
    store.skipRest();
    await tester.pump();
    expect(calls.map((call) => call.method), ['cancel']);

    calls.clear();
    final plank = store.exercises.firstWhere((e) => e.id == 'plank');
    store.discardWorkout();
    store.startFreeWorkout([plank]);
    store.beginWorkout();
    store.startSetTimer(store.activeWorkout!.exercises.first.sets.first);
    await tester.pump();
    final timed = calls.singleWhere((call) => call.method == 'scheduleSet');
    expect(
      (timed.arguments as Map)['endsAt'],
      clock.now().add(const Duration(seconds: 30)).millisecondsSinceEpoch,
    );
    expect((timed.arguments as Map)['title'], plank.name);

    calls.clear();
    store.toggleSetTimerPause();
    await tester.pump();
    expect(calls.map((call) => call.method), ['cancelSet']);
    semantics.dispose();
    await disposeTree(tester);
  });

  testWidgets('a set timed to its end is done without the workout page, when '
      'the app comes back', (tester) async {
    usePhoneViewport(tester);
    final clock = FakeClock();
    final store = AppStore(clock: clock.now, isOnboarded: true);
    final plank = store.exercises.firstWhere((e) => e.id == 'plank');
    store
      ..startFreeWorkout([plank])
      ..beginWorkout()
      ..startSetTimer(store.activeWorkout!.exercises.first.sets.first);
    await tester.pumpWidget(MishirubeApp(store: store));
    expect(find.byType(ActiveWorkoutScreen), findsNothing, reason: 'on Today');

    clock.advance(const Duration(minutes: 5));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    final set = store.activeWorkout!.exercises.first.sets.first;
    expect(set.isDone, isTrue);
    expect(set.durationSeconds, 30, reason: 'the time planned');
    expect(store.setTimer, isNull);
    expect(store.restEndsAt, isNotNull, reason: 'the rest follows');
    await disposeTree(tester);
  });

  testWidgets('ticking a set rests on the page and names a record', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final semantics = tester.ensureSemantics();
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await tester.pumpWidget(MishirubeApp(store: store));
    await _startFromRoutine(tester);

    await tester.tap(find.bySemanticsLabel(RegExp('^第 1 組完成')).first);
    await tester.pump();
    expect(find.text('2:00'), findsOneWidget);
    expect(find.textContaining('個人紀錄 ·'), findsOneWidget);
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
    await _startFromRoutine(tester);
    final sets = store.activeWorkout!.currentExercise.sets;
    final count = sets.length;
    final weight = sets.first.weightKg;
    final reps = sets.first.reps;
    final squat = store.activeWorkout!.currentExercise.exercise;
    final source = relativeLoadReference(
      squat,
      store.exerciseHistory(squat),
      store.activeWorkout!.startedAt,
    )!;
    final reference = source.oneRepMaxKg!;
    final percent = (weight / reference * 100).round();
    expect(find.text('相對負荷 $percent%'), findsWidgets);

    await tester.tap(find.bySemanticsLabel(RegExp('^編輯第 1 組')).first);
    await tester.pumpAndSettle();
    final dialog = find.byType(AppDialog);
    expect(find.textContaining('每邊'), findsOneWidget, reason: 'a barbell');
    expect(
      find.descendant(
        of: dialog,
        matching: find.text(
          '估計最大重量 ${formatWeight(reference)} kg · '
          '${source.date.month} 月 ${source.date.day} 日 · Epley 估計',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('相對負荷 $percent%')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('增加 2.5 kg'));
    await tester.pump();
    final updatedPercent = ((weight + 2.5) / reference * 100).round();
    expect(
      find.descendant(of: dialog, matching: find.text('相對負荷 $updatedPercent%')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('多 1 次'));
    await tester.tap(find.widgetWithText(SelectChip, '2'));
    await tester.pump();
    expect(
      find.descendant(of: dialog, matching: find.text('相對負荷 $updatedPercent%')),
      findsOneWidget,
    );
    await _tapText(tester, '儲存');
    final edited = store.activeWorkout!.currentExercise.sets.first;
    expect(edited.weightKg, weight + 2.5);
    expect(edited.reps, reps + 1);
    expect(edited.rir, 2);
    expect(find.text('相對負荷 $updatedPercent%'), findsWidgets);

    await tester.tap(find.bySemanticsLabel(RegExp('^編輯第 1 組')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SelectChip, '未記'));
    await _tapText(tester, '儲存');
    expect(store.activeWorkout!.currentExercise.sets.first.rir, isNull);
    expect(
      store.backend.training.active()!.currentExercise.sets.first.rir,
      isNull,
    );

    await tester.tap(find.bySemanticsLabel(RegExp('^編輯第 1 組')).first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(SelectChip, '未記'), findsOneWidget);
    await tester.tap(find.byTooltip('增加 2.5 kg'));
    await tester.tap(find.widgetWithText(SelectChip, '3'));
    await _tapText(tester, '取消');
    expect(
      store.activeWorkout!.currentExercise.sets.first.weightKg,
      weight + 2.5,
    );
    expect(store.activeWorkout!.currentExercise.sets.first.rir, isNull);

    await tester.tap(find.bySemanticsLabel(RegExp('^編輯第 1 組')).first);
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

      await _openRoutine(tester);
      await _tapText(tester, '加入動作');
      await tester.tap(find.byTooltip('篩選'));
      await tester.pumpAndSettle();
      await _tapText(tester, '槓鈴');
      await tester.tap(find.textContaining('個動作').last);
      await tester.pumpAndSettle();
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
        of: find.text('2026年9月').hitTestable(),
        matching: find.byType(HeaderAction),
      ),
    );
    await tester.tap(find.text('2026年9月').hitTestable());
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
    expect(popover.left, button.left, reason: 'from the leading edge');

    // A future month settles back to the latest one.
    await tester.drag(september, const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(find.text('2026年9月'), findsOneWidget);

    await tester.drag(september, const Offset(0, 60));
    await tester.pumpAndSettle();
    expect(find.text('2026年8月'), findsOneWidget);

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
    expect(find.text('2026年9月'), findsOneWidget);
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

  testWidgets('a bath is started from the add menu and ends as an entry', (
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
        matching: find.text('洗澡'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('開始'));
    await tester.pumpAndSettle();
    expect(store.activeSession, isA<ActiveBath>());

    clock.advance(const Duration(minutes: 6, seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('6:05'), findsWidgets, reason: 'the clock is running');

    await tester.tap(find.bySemanticsLabel('返回'));
    await tester.pumpAndSettle();
    expect(find.textContaining('洗澡進行中'), findsOneWidget);
    expect(
      find.byTooltip('暫停洗澡'),
      findsNothing,
      reason: 'a bath has nothing to pause',
    );

    await tester.tap(find.byTooltip('結束洗澡'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('結束並儲存'));
    await tester.pumpAndSettle();

    expect(store.activeSession, isNull);
    expect(
      find.text('6 分'),
      findsWidgets,
      reason: 'the entry shows its length',
    );
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
    await _startFromRoutine(tester);
    await tester.pump();
    await tester.pump(_pageTransition);
    expect(store.activeSession, isA<ActiveActivity>());
    expect(find.textContaining('騎自行車進行中，先結束才能開始'), findsOneWidget);
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

  testWidgets('a drafted amount reads beside the time, not in the name', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    const salad = DraftItem(name: '總匯沙拉', amount: '180 g', kcal: 178);
    final logged = store.backend.nutrition.logDraft(
      const MealDraft(
        items: [salad],
        provider: AiProviderKind.ollamaCloud,
        model: 'm',
      ),
      [salad],
    ).single;
    await pumpScreen(tester, const DailyNutritionScreen(), store: store);
    await tester.dragUntilVisible(
      find.text('總匯沙拉'),
      find.byType(CustomScrollView).hitTestable().first,
      _scrollStep,
    );

    expect(find.text('總匯沙拉'), findsOneWidget);
    expect(find.text('${logged.timeLabel} · 180 g'), findsOneWidget);
    expect(find.text('AI 估計'), findsNothing, reason: 'only on its page');

    await _tapText(tester, '總匯沙拉');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('· ${logged.timeLabel} · 180 g'),
      findsOneWidget,
      reason: "the meal's page says it by the time too",
    );
    expect(
      find.descendant(
        of: find.byType(MealSummaryCard),
        matching: find.textContaining('估計'),
      ),
      findsNothing,
    );
    expect(
      find.text('Ollama Cloud / m 估計'),
      findsOneWidget,
      reason: 'last on the page, naming the AI that drafted it',
    );

    await tester.ensureVisible(find.text('Ollama Cloud / m 估計'));
    await tester.tap(find.text('Ollama Cloud / m 估計'));
    await tester.pumpAndSettle();
    expect(find.byType(AiSettingsScreen), findsOneWidget);
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

    final trainingRow = find.widgetWithText(NavRow, '訓練');
    await tester.dragUntilVisible(
      trainingRow,
      find.byType(CustomScrollView).hitTestable().first,
      _scrollStep,
    );
    await Scrollable.ensureVisible(tester.element(trainingRow), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(trainingRow);
    await tester.pumpAndSettle();
    expect(find.text('訓練趨勢'), findsWidgets);
    await _tapText(tester, '每日紀錄');
    await tester.pumpAndSettle();
    await _tapText(tester, MuscleFigure.female.labelIn(testL10n));
    await tester.pumpAndSettle();

    expect(
      figureIn(backend),
      MuscleFigure.female,
      reason: 'the choice of drawing is stored, so it survives a restart',
    );
    await disposeTree(tester);
  });

  testWidgets('the muscle page lists every muscle, trained or not', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const MuscleTrendsScreen(), store: store);

    expect(
      find.text(MuscleGroup.glutes.labelIn(testL10n)),
      findsOneWidget,
      reason: 'the most trained leads',
    );
    // The last of them never trained in the demo records: it is still
    // there, so the page says what the span is missing.
    final untrained = find.text(MuscleGroup.core.labelIn(testL10n));
    await tester.dragUntilVisible(
      untrained,
      find.byType(CustomScrollView).hitTestable().first,
      _scrollStep,
    );
    expect(untrained, findsOneWidget);
    expect(tester.takeException(), isNull);
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

    final delta = find.textContaining(RegExp('[−+][0-9]'));
    // The areas' summaries carry signed figures too, so several can come
    // into view at once: scroll until any has.
    for (
      var step = 0;
      step < 50 && delta.hitTestable().evaluate().isEmpty;
      step++
    ) {
      await tester.drag(
        find.byType(CustomScrollView).hitTestable().first,
        _scrollStep,
      );
      await tester.pump();
    }
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
    await pumpScreen(tester, FoodEditScreen(meal: before), store: store);

    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(NumberFieldRow, '熱量'),
        matching: find.byType(TextField),
      ),
      '700',
    );
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

  testWidgets('choosing one exercise from its details answers at once', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    List<ExerciseDefinition>? chosen;
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => chosen = await Navigator.of(context)
              .push<List<ExerciseDefinition>>(
                MaterialPageRoute(
                  builder: (_) =>
                      const ExercisePickerScreen(purpose: PickerPurpose.single),
                ),
              ),
          child: const Text('open'),
        ),
      ),
      store: store,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '深蹲');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.info_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrimaryButton, '選擇動作'));
    await tester.pumpAndSettle();

    expect(chosen, hasLength(1), reason: 'one answer, with nothing to confirm');
    expect(find.byType(ExercisePickerScreen), findsNothing);
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
      (tester.widget<NavRow>(row).leading! as Row).children,
      hasLength(1),
      reason: 'only its picture: nothing to select, so no selection box',
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

  testWidgets('height and a scale reading give BMI and a history', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.journal.recordWeight(72.4);
    await pumpScreen(tester, const BodyScreen(), store: store);

    expect(find.text('未設定'), findsOneWidget);
    await _tapText(tester, '身高');
    await tester.enterText(find.byKey(const ValueKey('body-height')), '175');
    await _tapText(tester, '儲存');
    await tester.pumpAndSettle();
    expect(find.text('23.6 · 健康體重'), findsOneWidget);
    // Let the toast from saving the height go.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await _tapText(tester, '記錄身體組成');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('body-bodyFat')), '18.2');
    await tester.enterText(
      find.byKey(const ValueKey('body-skeletalMuscle')),
      '33.1',
    );
    await _tapText(tester, '儲存');
    await tester.pumpAndSettle();
    expect(store.backend.journal.latestBodyReadings(), hasLength(3));
    expect(find.text('13.2 kg'), findsOneWidget, reason: 'fat mass');

    await _tapText(tester, '骨骼肌');
    expect(find.text('33.1 kg'), findsWidgets);
    expect(find.text('體脂計估計，請用同一台比較'), findsOneWidget);

    await _tapText(tester, '33.1 kg');
    await _tapText(tester, '刪除這筆紀錄');
    expect(
      store.backend.journal.latestBodyReadings()[BodyMetric.skeletalMuscle],
      isNull,
    );
    expect(find.text('沒有紀錄'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('a photo of the scale fills the body composition form', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final backend = Backend.inMemory(clock: FakeClock().now);
    final store = AppStore(
      clock: FakeClock().now,
      isOnboarded: true,
      backend: backend,
      ai: AiService(
        backend.db,
        secrets: MemorySecretStore(),
        drafters: const {},
        labelReader: _Lines(['體脂率  18.2 %', '骨骼肌量  33.1 kg', '體重 72.4 kg']),
      ),
    );
    await pumpScreen(
      tester,
      BodyReadingEntryScreen(takePhoto: (_) async => '/scale.jpg'),
      store: store,
    );

    await tester.tap(find.bySemanticsLabel('拍照讀取身體組成'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('照片讀到 2 項，請核對'),
      200,
      scrollable: _pageScroll,
    );
    expect(find.text('照片讀到 2 項，請核對'), findsOneWidget);
    expect(
      store.backend.journal.latestBodyReadings(),
      isEmpty,
      reason: 'not yet',
    );

    await _tapText(tester, '儲存');
    expect(
      store.backend.journal
          .latestBodyReadings()[BodyMetric.skeletalMuscle]
          ?.value,
      33.1,
    );
    await disposeTree(tester);
  });

  testWidgets('a photo of measurements fills the girth form', (tester) async {
    usePhoneViewport(tester);
    final backend = Backend.inMemory(clock: FakeClock().now);
    final store = AppStore(
      clock: FakeClock().now,
      isOnboarded: true,
      backend: backend,
      ai: AiService(
        backend.db,
        secrets: MemorySecretStore(),
        drafters: const {},
        labelReader: _Lines(['腰圍 82.5 cm', '臀圍 96 cm']),
      ),
    );
    await pumpScreen(
      tester,
      MeasurementEntryScreen(takePhoto: (_) async => '/tape.jpg'),
      store: store,
    );

    await tester.tap(find.bySemanticsLabel('拍照讀取圍度'));
    await tester.pumpAndSettle();
    await _tapText(tester, '儲存');
    expect(
      store.backend.journal
          .latestMeasurements()[MeasurementSite.waist]
          ?.centimetres,
      82.5,
    );
    await disposeTree(tester);
  });

  testWidgets('a scale\'s weight and figures are logged and kept as one', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.provenance.setShowsDemo(false);
    await pumpScreen(tester, const BodyReadingEntryScreen(), store: store);

    await tester.enterText(find.byKey(const ValueKey('body-weight')), '72.4');
    await tester.enterText(find.byKey(const ValueKey('body-bodyFat')), '17.8');
    await _tapText(tester, '儲存');
    await tester.pumpAndSettle();
    final weight = store.backend.journal.weightOn(store.now())!;
    expect(weight.weightKg, 72.4);
    final session = store.backend.journal.bodySession(weight.sessionId!)!;
    expect(session.readings.single.metric, BodyMetric.bodyFat);
    await disposeTree(tester);

    await pumpScreen(
      tester,
      JournalDetailScreen(id: weight.id, at: weight.measuredAt),
      store: store,
    );
    expect(find.text('72.4 kg'), findsOneWidget);
    expect(find.text('17.8%'), findsOneWidget, reason: 'read together');
    await _tapText(tester, '刪除這次量測');
    expect(store.backend.journal.bodySession(session.id), isNull);
    expect(
      store.backend.journal.latestBodyReadings()[BodyMetric.bodyFat],
      isNull,
      reason: 'the figures went with the weight',
    );
    await disposeTree(tester);
  });

  testWidgets('a figure out of range is refused, not saved', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const BodyReadingEntryScreen(), store: store);

    await tester.enterText(find.byKey(const ValueKey('body-bodyFat')), '182');
    await _tapText(tester, '儲存');
    await tester.scrollUntilVisible(
      find.textContaining('體脂率請輸入'),
      200,
      scrollable: _pageScroll,
    );
    expect(find.textContaining('體脂率請輸入'), findsOneWidget);
    expect(store.backend.journal.latestBodyReadings(), isEmpty);
    await disposeTree(tester);
  });

  testWidgets('a night on the sleep trend\'s week reads out when touched', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.journal.recordSleep(const Duration(hours: 7));
    await _openSleepWeek(tester, store);

    final chart = find.byType(MiniBarChart);
    await tester.scrollUntilVisible(chart, 200, scrollable: _pageScroll);
    // Mid-screen: found at the bottom edge, most of it is still below.
    await Scrollable.ensureVisible(tester.element(chart), alignment: 0.5);
    await tester.pumpAndSettle();
    expect(find.text('平均 7 小時 · 1 晚'), findsOneWidget);
    await tester.tapAt(tester.getRect(chart).centerRight - const Offset(4, 0));
    await tester.pump();
    expect(find.textContaining('· 7 小時'), findsOneWidget);
    expect(find.text('平均 7 小時 · 1 晚'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('a night that met the sleep goal carries a check', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final now = store.now();
    for (final (back, hours) in [(0, 7), (1, 9)]) {
      final woke = DateTime(now.year, now.month, now.day - back, 7);
      store.backend.journal.recordSleep(
        Duration(hours: hours),
        at: woke,
        startedAt: woke.subtract(Duration(hours: hours)),
      );
    }
    store.backend.sleep.setGoal(const Duration(hours: 8));
    await _openSleepWeek(tester, store);

    final chart = find.byType(MiniBarChart);
    await tester.scrollUntilVisible(chart, 200, scrollable: _pageScroll);
    await tester.pumpAndSettle();
    expect(tester.widget<MiniBarChart>(chart).goal, 8 * 60);
    expect(
      find.descendant(of: chart, matching: find.byIcon(Icons.verified)),
      findsOneWidget,
      reason: 'the nine-hour night, not the seven-hour one',
    );
    final badge = find.ancestor(
      of: find.byIcon(Icons.verified),
      matching: find.byType(AspectRatio),
    );
    final bar = find.ancestor(of: badge, matching: find.byType(Container));
    expect(
      tester.getSize(badge).width,
      tester.getSize(bar.first).width - 4,
      reason: 'as wide as its bar, less a hairline of padding',
    );
    expect(find.textContaining('達成 1 晚'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('a sleep goal is set on the sleep page', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.journal.recordSleep(const Duration(hours: 7));
    await pumpScreen(tester, const SleepScreen(), store: store);

    final goalRow = find.widgetWithText(NavRow, '睡眠目標');
    await tester.scrollUntilVisible(goalRow, 200, scrollable: _pageScroll);
    expect(
      find.descendant(of: goalRow, matching: find.text('未設定')),
      findsOneWidget,
    );
    await _tapText(tester, '睡眠目標');
    await _tapText(tester, '儲存');
    expect(store.backend.sleep.goal, const Duration(hours: 8));
    // The summary is at the top, above the goal row.
    await tester.scrollUntilVisible(
      find.text('目標 8 小時 · 少 1 小時'),
      -200,
      scrollable: _pageScroll,
    );
    expect(find.text('目標 8 小時 · 少 1 小時'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('the sleep debt sums 14 days apart from extra sleep', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final now = store.now();
    void slept(List<(int, int)> nights) {
      for (final (back, hours) in nights) {
        final woke = DateTime(now.year, now.month, now.day - back, 7);
        store.backend.journal.recordSleep(
          Duration(hours: hours),
          at: woke,
          startedAt: woke.subtract(Duration(hours: hours)),
        );
      }
    }

    slept([(0, 7), (1, 9), (2, 5)]);
    await pumpScreen(tester, const SleepScreen(), store: store);
    final needs = find.text('需要近 14 天有 5 天紀錄（目前 3 天）');
    await tester.scrollUntilVisible(needs, 200, scrollable: _pageScroll);
    expect(find.text('— 小時'), findsOneWidget, reason: 'three nights');
    await disposeTree(tester);

    slept([(3, 8), (4, 8)]);
    await pumpScreen(tester, const SleepScreen(), store: store);
    final line = find.text('近 14 天 · 多睡 1.0 小時');
    await tester.scrollUntilVisible(line, 200, scrollable: _pageScroll);
    expect(find.widgetWithText(PageSection, '睡眠債'), findsOneWidget);
    expect(find.text('4.0 小時'), findsOneWidget, reason: '1 + 3, not net of 1');
    expect(find.text('近 7 天 4.0 小時 · 多睡 1.0 小時'), findsOneWidget);
    expect(find.text('初步'), findsOneWidget, reason: 'under a week');
    expect(find.text('以 8 小時計'), findsOneWidget);
    expect(find.text('9 天沒有紀錄'), findsOneWidget);

    await tester.tap(line);
    await tester.pumpAndSettle();
    // Each of the 14 days, under the trend.
    // Each day's sleep over its date, how far it was from the goal at
    // its end.
    Finder dayRow(String slept, String gap) => find.ancestor(
      of: find.text(gap, skipOffstage: false),
      matching: find.widgetWithText(NavRow, slept, skipOffstage: false),
    );
    await tester.scrollUntilVisible(
      dayRow('9 小時', '多 1 小時'),
      200,
      scrollable: _pageScroll,
    );
    expect(dayRow('7 小時', '少 1 小時'), findsOneWidget);
    expect(dayRow('9 小時', '多 1 小時'), findsOneWidget);
    expect(find.text('沒有紀錄', skipOffstage: false), findsNWidgets(9));
    await disposeTree(tester);
  });

  testWidgets('a sleep is logged by when it began and ended', (tester) async {
    usePhoneViewport(tester);
    final clock = FakeClock();
    final store = AppStore(clock: clock.now, isOnboarded: true);
    await pumpScreen(tester, const SleepEntryScreen(), store: store);

    await _tapText(tester, '小睡');
    await tester.enterText(find.byType(TextField), '午餐後');
    await _tapText(tester, '儲存');
    final nap = store.backend.journal
        .recentSleep(const Duration(days: 1))
        .firstWhere((entry) => entry.kind == SleepKind.nap);
    expect(nap.duration, const Duration(minutes: 30));
    expect(nap.startedAt, clock.now().subtract(const Duration(minutes: 30)));
    expect(nap.note, '午餐後');
    await disposeTree(tester);
  });

  testWidgets('a workout of my own is swiped away, and undone', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final own = store.routines.last;
    final count = store.routines.length;
    await pumpScreen(tester, const TrainingScreen(), store: store);

    await tester.drag(find.text(own.name), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('刪除'));
    // Not settled: the undo's countdown would run out.
    await tester.pump(const Duration(milliseconds: 300));
    expect(store.routines, hasLength(count - 1));

    await tester.tap(find.text('復原'));
    await tester.pump();
    expect(store.routines, hasLength(count));
    await disposeTree(tester);
  });

  testWidgets('an exercise is replaced by any from the library', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..startWorkout();
    final current = store.activeWorkout!.currentExercise.exercise;
    final other = store.exercises.firstWhere(
      (exercise) =>
          exercise.id != current.id &&
          !store
              .substitutesFor(current)
              .any((o) => o.exercise.id == exercise.id),
    );
    await pumpScreen(tester, const SubstituteExerciseScreen(), store: store);

    await _tapText(tester, '從所有動作選擇');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, other.name);
    await tester.pumpAndSettle();
    await tester.tap(find.text(other.name).last);
    await tester.pumpAndSettle();
    await _tapText(tester, '替換');

    expect(store.activeWorkout!.currentExercise.exercise.id, other.id);
    await disposeTree(tester);
  });

  testWidgets('a workout pasted as text is read and started', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const TrainingScreen(), store: store);

    await _tapText(tester, '一句話');
    await tester.enterText(
      find.byType(TextField).first,
      '1. 槓鈴深蹲 4×8 60kg\n2. 不存在的動作名稱 3x5',
    );
    await tester.pump();
    await _tapText(tester, '產生草稿');
    expect(find.text('4 組 × 8 下 · 60 kg'), findsOneWidget);
    expect(find.text('找不到這個動作'), findsOneWidget);

    await _tapText(tester, '開始訓練');
    final workout = store.activeWorkout!;
    expect(
      workout.exercises,
      hasLength(1),
      reason: 'the unmatched is left out',
    );
    expect(workout.exercises.single.exercise.name, '槓鈴深蹲');
    expect(
      [for (final set in workout.exercises.single.sets) set.weightKg],
      [60.0, 60.0, 60.0, 60.0],
    );
    expect(workout.isReady, isTrue);
    await disposeTree(tester);
  });

  testWidgets('relative load stays the same after finishing and reopening', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final semantics = tester.ensureSemantics();
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await tester.pumpWidget(MishirubeApp(store: store));
    await _startFromRoutine(tester);
    final workout = store.activeWorkout!;
    final squat = workout.currentExercise.exercise;
    final source = relativeLoadReference(
      squat,
      store.exerciseHistory(squat),
      workout.startedAt,
    )!;
    final set = workout.currentExercise.sets.first;
    final label = '相對負荷 ${relativeLoadPercent(set.weightKg, source)!.round()}%';
    expect(find.text(label), findsWidgets);

    // 還留幾下 is optional: cleared here, then unrecorded all the way through.
    await tester.tap(find.bySemanticsLabel(RegExp('^編輯第 1 組')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SelectChip, '未記'));
    await _tapText(tester, '儲存');
    expect(store.activeWorkout!.currentExercise.sets.first.rir, isNull);
    expect(find.text(label), findsWidgets, reason: 'RIR does not change it');

    await tester.tap(find.bySemanticsLabel(RegExp('^第 1 組完成')).first);
    await tester.pump();
    expect(store.activeWorkout!.currentExercise.sets.first.rir, isNull);
    // Let the record's toast go: the rest card is a line taller with the
    // next set, which lifts it over the dialog.
    await tester.pump(const Duration(seconds: 4));
    await _tapText(tester, '結束');
    await _tapText(tester, '結束並儲存');
    expect(find.byType(WorkoutSummaryScreen), findsOneWidget);
    expect(find.text(label), findsWidgets);
    expect(store.lastFinishedWorkout!.exercises.first.sets.first.rir, isNull);
    semantics.dispose();
    await disposeTree(tester);

    await pumpScreen(
      tester,
      WorkoutSummaryScreen(workoutId: workout.id),
      store: store,
    );
    expect(find.text(label), findsWidgets);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('a finished workout is deleted from its page, with an undo', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..startWorkout()
      ..completeNextSet()
      ..finishWorkout();
    final workout = store.lastFinishedWorkout!;
    await pumpScreen(tester, const LogScreen(), store: store);
    pushPage(
      tester.element(find.byType(LogScreen)),
      WorkoutSummaryScreen(workoutId: workout.id),
    );
    await tester.pumpAndSettle();

    await _tapText(tester, '刪除這筆紀錄');
    await tester.pump(_pageTransition);
    expect(find.byType(WorkoutSummaryScreen), findsNothing);
    expect(store.lastFinishedWorkout?.id, isNot(workout.id));

    await tester.tap(find.text('復原'));
    await tester.pump();
    expect(store.lastFinishedWorkout?.id, workout.id);
    await disposeTree(tester);
  });

  testWidgets('a finished workout is looked over before it is kept', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..startWorkout()
      ..completeNextSet()
      ..completeNextSet()
      ..finishWorkout();
    final before = store.routines.length;
    await pumpScreen(tester, const LogScreen(), store: store);
    pushPage(
      tester.element(find.byType(LogScreen)),
      WorkoutSummaryScreen(workoutId: store.lastFinishedWorkout!.id),
    );
    await tester.pumpAndSettle();

    await _tapText(tester, '存成課表');
    await tester.pumpAndSettle();
    expect(store.routines, hasLength(before), reason: 'nothing kept yet');
    expect(find.text('開始訓練'), findsNothing, reason: 'nothing to start');

    await tester.enterText(find.byType(TextField).first, '背日');
    await _tapText(tester, '新增組');
    await _tapText(tester, '儲存');
    await tester.pumpAndSettle();

    expect(find.byType(WorkoutSummaryScreen), findsOneWidget);
    expect(store.routines, hasLength(before + 1));
    final kept = store.routines.firstWhere((routine) => routine.name == '背日');
    expect(kept.exercises.first.sets, 3, reason: 'two done, one added');
    await disposeTree(tester);
  });

  testWidgets('a finished workout is corrected from its page', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..startWorkout()
      ..completeNextSet()
      ..finishWorkout();
    final workout = store.lastFinishedWorkout!;
    final before = workout.completedSets;
    await pumpScreen(tester, const LogScreen(), store: store);
    pushPage(
      tester.element(find.byType(LogScreen)),
      WorkoutSummaryScreen(workoutId: workout.id),
    );
    await tester.pumpAndSettle();

    await _tapText(tester, '編輯這筆紀錄');
    await tester.pumpAndSettle();
    await _tapText(tester, '新增組');
    await _tapText(tester, '儲存');
    await tester.pumpAndSettle();

    expect(find.byType(WorkoutSummaryScreen), findsOneWidget);
    expect(store.workoutById(workout.id)!.completedSets, before + 1);
    await disposeTree(tester);
  });

  testWidgets('我的 sums up what was done and keeps the birth year', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..startWorkout()
      ..completeNextSet()
      ..finishWorkout();
    await pumpScreen(tester, const MeScreen(), store: store);

    expect(
      find.text('${store.finishedWorkoutCount} 次', findRichText: true),
      findsWidgets,
      reason: 'the workouts done so far',
    );
    expect(find.text('睡眠目標'), findsOneWidget, reason: 'goals together');

    await _tapText(tester, '出生年');
    await tester.enterText(find.byType(TextField), '1995');
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();
    expect(store.birthYear, 1995);
    expect(find.text('1995 年'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('the step goal is set from 我的 as from the steps page', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const MeScreen(), store: store);

    final row = find.widgetWithText(NavRow, '步數目標');
    await tester.scrollUntilVisible(row, 200, scrollable: _pageScroll);
    expect(
      find.descendant(of: row, matching: find.text('未設定')),
      findsOneWidget,
      reason: 'the app picks no goal of its own',
    );
    await _tapText(tester, '步數目標');
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();
    expect(store.backend.activity.stepGoal, 5000);
    expect(
      find.descendant(of: row, matching: find.text('5,000 步')),
      findsOneWidget,
    );
    await disposeTree(tester);
  });

  testWidgets('a sore muscle is marked before starting', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const RoutineDetailScreen(), store: store);
    final first = store.routine.exercises.first;

    await _tapText(
      tester,
      first.exercise.primaryMuscles.first.labelIn(testL10n),
    );
    // The muscles are chosen under the plan; its cards are above.
    final lighter = find.text('今天少 1 組');
    for (var i = 0; i < 20 && lighter.evaluate().isEmpty; i++) {
      await tester.drag(
        find.byType(CustomScrollView).hitTestable().first,
        const Offset(0, 200),
      );
      await tester.pump();
    }
    expect(lighter, findsWidgets);
    await disposeTree(tester);
  });

  testWidgets('two planned exercises are joined into a superset', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const RoutineDetailScreen(), store: store);
    final options = find.byTooltip(
      '${store.routine.exercises.first.exercise.name}的選項',
    );

    await tester.tap(options);
    await tester.pumpAndSettle();
    await _tapText(tester, '與下一個組成超級組');
    expect(store.routine.exercises.first.joinsNext, isTrue);
    expect(find.widgetWithText(TagChip, '超級組'), findsNWidgets(2));

    await tester.tap(options);
    await tester.pumpAndSettle();
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

  testWidgets('a new workout opens at once, named later by what it trains', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const TrainingScreen(), store: store);
    final before = store.routines.length;

    await _tapText(tester, '新增課表');
    await tester.pumpAndSettle();

    expect(store.routines, hasLength(before + 1));
    expect(store.routine.name, '新的課表');
    expect(find.text('新的課表'), findsWidgets, reason: 'no name dialog first');
    await disposeTree(tester);
  });

  testWidgets('a planned set is typed in place and more are added', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const RoutineDetailScreen(), store: store);
    final sets = store.routine.exercises.first.sets;

    final weight = find.bySemanticsLabel('第 1 組重量').first;
    await tester.tap(weight);
    await tester.enterText(find.byType(TextField).first, '100');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(store.routine.exercises.first.loads.first.weightKg, 100);

    await _tapText(tester, '新增組');
    expect(store.routine.exercises.first.sets, sets + 1);
    await disposeTree(tester);
  });

  testWidgets('a workout starts from exercises of an earlier one', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final past = store.recentWorkouts.first;
    await pumpScreen(tester, const TrainingScreen(), store: store);

    await tester.tap(find.text('載入紀錄'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(past.routineName).first);
    await tester.pumpAndSettle();
    await _tapText(tester, '選擇全部');
    await _tapText(tester, '開始訓練（${past.exercises.length} 個動作）');

    final started = store.activeWorkout!;
    expect(started.routineId, isNull);
    expect(
      started.exercises.first.exercise.id,
      past.exercises.first.exercise.id,
    );
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

  testWidgets('a run reads its pace in minutes and seconds a kilometre', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.provenance.setShowsDemo(false);
    await pumpScreen(tester, const RecordActivityScreen(), store: store);

    await tester.tap(find.text('運動類型'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('跑步').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('activity-distance')),
      '4',
    );
    await tester.pump();
    expect(
      find.text('配速 7:30 /km'),
      findsOneWidget,
      reason: 'half an hour over 4 km, not 0:07',
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

    // Centred first, clear of the pinned month switch and chips.
    await _tapText(tester, '騎自行車');
    await tester.pumpAndSettle();
    expect(find.text('平均速度'), findsOneWidget, reason: 'a ride reads as speed');

    await tester.tap(find.text('編輯內容'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('60 分'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();
    expect(
      find.text('1:00:00', findRichText: true),
      findsOneWidget,
      reason: 'the detail shows the fix',
    );

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
        find.text(category.labelIn(testL10n)),
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

    await _openRoutine(tester);
    final planned = [
      for (final exercise in store.routine.exercises) exercise.exercise.name,
    ];
    Future<void> choose(String exercise, String edit) async {
      await tester.tap(find.byTooltip('$exercise的選項'));
      await tester.pumpAndSettle();
      await _tapText(tester, edit);
    }

    await choose(planned[0], '下移');
    expect(store.routine.exercises.first.exercise.name, planned[1]);

    await choose(planned[1], '移除');
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

    await _openRoutine(tester);
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

    // Below the recent meals, so looked for further down.
    await tester.dragUntilVisible(
      find.text('沒有食物'),
      find.byType(CustomScrollView).first,
      _scrollStep,
    );
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
    expect(
      store.todayKcal,
      before + 247.5,
      reason: '165 × 1.5: the day keeps what the portion came to',
    );
    expect(store.todayMeals.last.proteinGrams, 46.5, reason: '31 × 1.5');
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
    // Down the form in order: a lazy list only builds what is near.
    await _enterBeside(tester, '糖', '4.5');
    await _enterBeside(tester, '咖啡因', '20');
    await tester.pump();

    await _tapText(tester, '只建立');
    await tester.pumpAndSettle();
    final saved = store.backend.nutrition.searchFoods('無糖紅茶').single;
    expect(saved.nutrients[Nutrient.caffeine], 120);
    expect(saved.nutrients[Nutrient.sugar], 27, reason: 'the whole label');
    expect(saved.caffeineBasis, CaffeineBasis.per100);
    await disposeTree(tester);
  });

  testWidgets('最近 lists every food eaten, a page at a time', (tester) async {
    usePhoneViewport(tester);
    final clock = FakeClock();
    final store = AppStore(clock: clock.now, isOnboarded: true);
    for (var i = 1; i <= 45; i++) {
      final food = store.backend.nutrition.saveFood(
        FoodItem(id: 'food-$i', name: '食物 $i', kcal: 100),
      );
      clock.advance(const Duration(minutes: 5));
      store.backend.nutrition.logPortion(FoodPortion(food, 1));
    }
    await pumpScreen(tester, const FoodSearchScreen(), store: store);

    await _tapText(tester, '更多');
    await tester.scrollUntilVisible(
      find.text('食物 1'),
      400,
      scrollable: _pageScroll,
      maxScrolls: 200,
    );
    expect(
      find.text('食物 1'),
      findsOneWidget,
      reason: 'the first food eaten, past the first page of 30',
    );
    await disposeTree(tester);
  });

  testWidgets('a search finds meals logged without a saved food', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final clock = FakeClock();
    final store = AppStore(clock: clock.now, isOnboarded: true);
    final nutrition = store.backend.nutrition;
    nutrition.logOnce(
      FoodPortion(const FoodItem(id: 'once', name: '米漿', kcal: 180), 1),
    );
    final rice = nutrition.saveFood(
      const FoodItem(id: 'rice', name: '白飯', kcal: 130),
    );
    clock.advance(const Duration(minutes: 5));
    nutrition.logPortion(FoodPortion(rice, 1));
    final before = store.todayMeals.length;
    await pumpScreen(tester, const FoodSearchScreen(), store: store);

    await tester.enterText(find.byType(TextField), '米漿');
    await tester.pumpAndSettle();
    final logged = find.descendant(
      of: find.byType(RecentMealRow),
      matching: find.text('米漿'),
    );
    expect(logged, findsOneWidget, reason: 'typed once, in no library');
    await tester.tap(find.byTooltip('加入米漿'));
    await tester.pumpAndSettle();
    expect(store.todayMeals.length, before + 1);

    // A meal from a saved food is that food's row, not a second one.
    await tester.enterText(find.byType(TextField), '白飯');
    await tester.pumpAndSettle();
    expect(find.byType(RecentMealRow), findsNothing);
    expect(
      find.descendant(of: find.byType(FoodRow), matching: find.text('白飯')),
      findsOneWidget,
    );
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
    expect(plate.map((m) => m.mealType).toSet(), {
      MealType.dinner,
    }, reason: 'the meal chosen on the page applies to the whole plate');
    await disposeTree(tester);
  });

  testWidgets('every nutrient is on the form without asking', (tester) async {
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

  testWidgets('the habitual meal label is filled in, and can be changed', (
    tester,
  ) async {
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

    expect(find.bySemanticsLabel(RegExp('目前午餐')), findsOneWidget);
    expect(find.text('套用'), findsNothing, reason: 'nothing left to accept');
    await disposeTree(tester);
  });

  testWidgets('＋ on a food eaten before puts the same portion on the plate', (
    tester,
  ) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final nutrition = store.backend.nutrition;
    final egg = FoodItem(id: nutrition.newFoodId(), name: '水煮蛋', kcal: 70);
    nutrition
      ..saveFood(egg)
      ..logPortion(FoodPortion(egg, 2));
    await pumpScreen(tester, const FoodSearchScreen(), store: store);

    final eggs = find.byTooltip('加入「水煮蛋」');
    for (var i = 0; i < 20 && eggs.evaluate().isEmpty; i++) {
      await tester.drag(
        find.byType(CustomScrollView).hitTestable().first,
        _scrollStep,
      );
      await tester.pump();
    }
    // Listed under 最近 and 自己的 alike; the first will do.
    final add = eggs.first;
    await Scrollable.ensureVisible(tester.element(add), alignment: 0.5);
    await tester.pump();
    await tester.tap(add);
    await tester.pump();
    expect(
      find.byTooltip('這一餐 · 1 項 · 140 kcal'),
      findsOneWidget,
      reason: 'two eggs, as last time, with no portion page in between',
    );
    await disposeTree(tester);
  });

  testWidgets('a recent meal is logged again from the first view', (
    tester,
  ) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const FoodSearchScreen(), store: store);
    final before = store.todayKcal;

    expect(find.text('近期用餐'), findsOneWidget);
    await tester.tap(find.byTooltip(RegExp('^加入(?!收藏)')).first);
    await tester.pump();
    expect(store.todayKcal, greaterThan(before));
    expect(find.text('復原'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('新增紀錄 on another day logs to that day', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final nutrition = store.backend.nutrition;
    final today = store.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    await pumpScreen(tester, const DailyNutritionScreen(), store: store);
    final page = find.byType(CustomScrollView).hitTestable().first;
    final addToday = find.text(testL10n.dockAddEntry);
    await tester.dragUntilVisible(addToday, page, _scrollStep);
    expect(addToday, findsOneWidget, reason: 'today needs no day named');

    await tester.tap(
      find.bySemanticsLabel(RegExp('^${yesterday.month} 月 ${yesterday.day} 日')),
    );
    await tester.pumpAndSettle();
    // The button says which day it logs to once that is not today.
    final label = testL10n.addEntryToDay(
      date: AppDates.of(testL10n).monthDay(yesterday),
    );
    await tester.dragUntilVisible(find.text(label), page, _scrollStep);
    expect(find.text(label), findsOneWidget);
    expect(addToday, findsNothing);
    final before = nutrition.mealsOn(yesterday).length;
    final todayBefore = nutrition.mealsOn(today).length;

    await _tapText(tester, label);
    await tester.pumpAndSettle();
    expect(find.byType(FoodSearchScreen), findsOneWidget);
    await tester.tap(find.byTooltip(RegExp('^加入(?!收藏)')).first);
    await tester.pump();

    expect(nutrition.mealsOn(yesterday), hasLength(before + 1));
    expect(nutrition.mealsOn(today), hasLength(todayBefore));
    final logged = nutrition.mealsOn(yesterday).last;
    expect(logged.groupId, isNull, reason: 'a copy is a meal on its own');
    await disposeTree(tester);
  });

  testWidgets('a label\'s decimal energy is kept, and shown', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final before = store.todaySummary.kcal;
    store.backend.nutrition.logMeal(
      const MealEvent(
        id: 'soy-milk',
        name: '豆漿',
        timeLabel: '08:00',
        qualityTag: '手動',
        dishes: [],
        kcal: 55.5,
      ),
      eatenAt: store.now(),
    );
    await pumpScreen(tester, const DailyNutritionScreen(), store: store);

    expect(
      store.todaySummary.kcal,
      before + 55.5,
      reason: 'the day adds up what the records say, decimals included',
    );
    final figure = find.textContaining('55.5', findRichText: true);
    await tester.scrollUntilVisible(figure, 200, scrollable: _pageScroll);
    expect(
      figure,
      findsWidgets,
      reason: 'the row reads the label, not a rounded version of it',
    );
    await disposeTree(tester);
  });

  testWidgets('a night in the log opens its sleep page', (tester) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.journal.recordSleep(const Duration(hours: 7), score: 4);
    await pumpScreen(tester, const LogScreen(), store: store);

    await _tapText(tester, '睡眠 7 小時');
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

  testWidgets('the day\'s food is a card of its own, labelled 飲食', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const TodayScreen(), store: store);

    expect(
      find.widgetWithText(CategoryLabel, testL10n.moduleNutrition),
      findsOneWidget,
      reason: 'marked in the colour the module reads in',
    );
    expect(find.text('今日攝取'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('the food form carries the time a meal is logged at', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final at = DateTime(2026, 9, 18, 15, 40);

    // 快速記錄: the meal about to be logged, its time changeable there.
    await pumpScreen(
      tester,
      FoodEditScreen(initialName: '蛋糕', logsOnce: true, at: at),
      store: store,
    );
    expect(find.text('時間'), findsOneWidget);
    expect(
      find.textContaining(formatTimeOfDay(at)),
      findsOneWidget,
      reason: 'the time it will be logged at',
    );
    await _tapText(tester, '記錄');
    final logged = store.backend.nutrition
        .mealsOn(at)
        .firstWhere((meal) => meal.name == '蛋糕');
    expect(store.backend.nutrition.eatenAtOf(logged.id), at);
    await disposeTree(tester);

    // A logged meal is corrected at the time it was eaten, as before.
    await pumpScreen(tester, FoodEditScreen(meal: logged), store: store);
    expect(find.text('時間'), findsOneWidget);
    expect(find.textContaining(formatTimeOfDay(at)), findsOneWidget);
    await disposeTree(tester);

    // A food that is only saved was not eaten, so it carries no time.
    await pumpScreen(
      tester,
      FoodEditScreen(initialName: '蛋糕', logsOnce: false),
      store: store,
    );
    expect(find.text('時間'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('a food row opens that meal, not its day', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.nutrition.logMeal(
      MealEvent(
        id: 'today-lunch',
        name: '雞腿便當',
        timeLabel: '12:30',
        qualityTag: '手動',
        dishes: const [],
        kcal: 780,
      ),
      eatenAt: store.now(),
    );
    await pumpScreen(tester, const TodayScreen(), store: store);

    final row = find.text('雞腿便當');
    await tester.dragUntilVisible(
      row,
      find.byType(CustomScrollView).hitTestable().first,
      _scrollStep,
    );
    await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(MealDetailScreen), findsOneWidget);
    expect(
      find.byType(DailyNutritionScreen),
      findsNothing,
      reason: 'the meal it names, not the day it was eaten on',
    );
    await disposeTree(tester);

    // The same row in 紀錄 opens the same page.
    await pumpScreen(tester, const LogScreen(), store: store);
    final logged = find.text('雞腿便當');
    await tester.dragUntilVisible(
      logged,
      find.byType(CustomScrollView).hitTestable().first,
      _scrollStep,
    );
    await Scrollable.ensureVisible(tester.element(logged), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(logged);
    await tester.pumpAndSettle();
    expect(find.byType(MealDetailScreen), findsOneWidget);
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
      find.widgetWithText(SectionLabel, '台灣'),
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
    expect(
      find.widgetWithText(SectionLabel, '台灣'),
      findsOneWidget,
      reason: 'chains are listed by the country their menu is for',
    );
    expect(find.text('星巴克（台灣）'), findsOneWidget);
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
    await tester.tap(find.text('星巴克（台灣） · 查看完整菜單'));
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
    for (final food in parseCatalogue({
      'brand': 'すき家',
      'market': 'jp',
      'sourceUrl': 'https://example.com',
      'checkedAt': '2026-09-08',
      'valueType': 'declared',
      'drinks': [
        {'id': 'gyudon', 'name': '牛丼', 'kind': 'food', 'kcal': 695},
      ],
    })) {
      store.backend.storage.foods.save(food, source: ChangeSource.catalogue);
    }
    await pumpScreen(tester, const MeScreen(), store: store);

    await _tapText(tester, '食物庫');
    await tester.pumpAndSettle();
    expect(find.text('自煮雞胸'), findsOneWidget, reason: 'own foods listed');
    expect(find.text('星巴克（台灣）'), findsOneWidget, reason: 'brands listed');
    expect(find.text('すき家（日本）'), findsOneWidget);

    // A country's chip keeps to its chains.
    await tester.tap(
      find.descendant(
        of: find.byType(FilterChipBar<String>),
        matching: find.text('日本'),
      ),
    );
    await tester.pump();
    expect(find.text('すき家（日本）'), findsOneWidget);
    expect(find.text('星巴克（台灣）'), findsNothing);
    expect(find.text('自煮雞胸'), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(FilterChipBar<String>),
        matching: find.text('全部'),
      ),
    );
    await tester.pump();

    // Searching narrows both.
    await tester.enterText(find.byType(TextField), '雞胸');
    await tester.pump();
    expect(find.text('自煮雞胸'), findsOneWidget);
    expect(find.text('星巴克（台灣）'), findsNothing);

    // An own food opens to be corrected.
    await tester.tap(find.text('自煮雞胸'));
    await tester.pumpAndSettle();
    expect(find.byType(FoodEditScreen), findsOneWidget);
    await tester.tap(find.byTooltip('返回').last);
    await tester.pumpAndSettle();

    // A brand opens its menu, to browse.
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.text('星巴克（台灣）'));
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

  testWidgets('the toast after a record opens that record', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    // The toast is app chrome: it opens the record through the shell,
    // as the dock opens a page.
    await tester.pumpWidget(MishirubeApp(store: store));
    await tester.pumpAndSettle();
    store.openFromChrome(const WaterScreen());
    await tester.pumpAndSettle();

    await _tapText(
      tester,
      '＋ ${NutritionViewModel(store.backend).glassMillilitres} mL',
    );
    final logged = store.backend.nutrition
        .mealsOn(store.now())
        .firstWhere((meal) => meal.isWater);
    // Not settled: the undo's countdown would run out and take the toast.
    final message = testL10n.waterLogged(millilitres: logged.millilitres ?? 0);
    expect(find.text(message), findsOneWidget, reason: 'the toast');

    await tester.tap(find.text(message));
    await tester.pumpAndSettle();
    expect(
      find.byType(MealDetailScreen),
      findsOneWidget,
      reason: 'the glass the toast was about',
    );
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
    await pumpScreen(tester, const WaterScreen(), store: store);
    final nutrition = NutritionViewModel(store.backend);
    addTearDown(nutrition.dispose);
    final glass = nutrition.glassMillilitres;

    expect(nutrition.todayWater.millilitres, 0, reason: 'coffee is not water');
    await _tapText(tester, '＋ $glass mL');

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

  testWidgets('the water reference is chosen, and a fast hour is warned', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const WaterScreen(), store: store);

    expect(find.text('國健署'), findsOneWidget, reason: 'prefilled in Taiwan');
    await _tapText(tester, '每日參考量');
    expect(find.text('族群參考值，實際需求因人而異'), findsOneWidget);
    await _tapText(tester, '不設定');
    await tester.pumpAndSettle();
    expect(store.backend.nutrition.waterReferenceMl, isNull);
    expect(find.text('未設定'), findsOneWidget);

    store.backend.nutrition
      ..logWater(600)
      ..logWater(600);
    await tester.pumpAndSettle();
    expect(find.textContaining('低血鈉'), findsOneWidget);
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

  testWidgets('meals logged apart are picked and merged, undoably', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final nutrition = store.backend.nutrition;
    final today = store.now();
    nutrition.deleteMeals([
      for (final meal in nutrition.mealsOn(today)) meal.id,
    ]);
    for (final (name, kcal) in [('蛋餅', 250.0), ('冰奶茶', 300.0)]) {
      nutrition.logMeal(
        MealEvent(
          id: name,
          name: name,
          timeLabel: '08:00',
          qualityTag: '手動',
          dishes: const [],
          kcal: kcal,
        ),
        eatenAt: today,
      );
    }
    await pumpScreen(tester, const DailyNutritionScreen(), store: store);

    await tester.tap(find.text('合併'));
    await tester.pump();
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNull,
      reason: 'one meal is nothing to merge',
    );
    await tester.tap(find.text('蛋餅'));
    await tester.tap(find.text('冰奶茶'));
    await tester.pump();
    await tester.tap(find.text('合併 2 筆成一餐'));
    await tester.pumpAndSettle();

    // Shown before it is done: the one meal, its sum, and a name for it
    // with the items' names standing in while it is blank.
    final preview = find.byType(MealChangePreviewScreen);
    expect(preview, findsOneWidget);
    expect(
      mealsOf(nutrition.mealsOn(today)),
      hasLength(2),
      reason: 'nothing merged yet',
    );
    expect(
      find.descendant(
        of: preview,
        matching: find.textContaining('550', findRichText: true),
      ),
      findsWidgets,
      reason: 'the sum it will be',
    );
    await tester.enterText(
      find.descendant(of: preview, matching: find.byType(TextField)),
      '早餐',
    );
    // What the meal has once for all its items: here, which sitting.
    await tester.tap(
      find.descendant(of: preview, matching: find.text('早餐')).last,
    );
    await tester.pump();
    expect(
      find.descendant(of: preview, matching: find.text('早餐')),
      findsWidgets,
    );
    await tester.tap(find.descendant(of: preview, matching: find.text('合併')));
    // Long enough for the page to close, well inside the undo's time.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(mealsOf(nutrition.mealsOn(today)), hasLength(1));
    expect(mealKcalOf(mealsOf(nutrition.mealsOn(today)).single), 550);
    expect(
      nutrition.nameOfMeal(mealsOf(nutrition.mealsOn(today)).single),
      '早餐',
    );
    expect(
      mealsOf(nutrition.mealsOn(today)).single.map((item) => item.mealType),
      everyElement(MealType.breakfast),
    );
    expect(find.textContaining('2 項'), findsOneWidget);

    await tester.tap(find.text('復原'));
    await tester.pump();
    expect(
      mealsOf(nutrition.mealsOn(today)),
      hasLength(2),
      reason: 'undo splits it',
    );
    expect(
      nutrition.mealsOn(today).map((item) => item.mealType),
      everyElement(isNull),
      reason: 'and takes back the sitting',
    );
    await disposeTree(tester);
  });

  testWidgets('a meal\'s row presses from edge to edge of its card', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final nutrition = store.backend.nutrition;
    final today = store.now();
    nutrition.deleteMeals([
      for (final meal in nutrition.mealsOn(today)) meal.id,
    ]);
    nutrition.logMeal(
      MealEvent(
        id: 'bento',
        name: '雞腿便當',
        timeLabel: '12:00',
        qualityTag: '手動',
        dishes: const [
          DishEntry(name: '雞腿', quantityLabel: '1 隻', subtitle: '手動'),
        ],
        kcal: 780,
      ),
      eatenAt: today,
    );
    await pumpScreen(tester, const DailyNutritionScreen(), store: store);
    await tester.scrollUntilVisible(
      find.text('雞腿便當'),
      200,
      scrollable: _pageScroll,
    );

    final card = tester.getRect(
      find.ancestor(of: find.text('雞腿便當'), matching: find.byType(AppCard)),
    );
    for (final text in ['雞腿便當', '雞腿']) {
      final pressed = tester.getRect(
        find
            .ancestor(of: find.text(text), matching: find.byType(InkWell))
            .first,
      );
      expect(
        pressed.left,
        card.left,
        reason: '$text: no inset to press around',
      );
      expect(pressed.right, card.right, reason: text);
    }
    await disposeTree(tester);
  });

  testWidgets('a meal opens to what it was, and the pencil edits it', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final nutrition = store.backend.nutrition;
    final today = store.now();
    nutrition.deleteMeals([
      for (final meal in nutrition.mealsOn(today)) meal.id,
    ]);
    nutrition.logMeal(
      MealEvent(
        id: 'bento',
        name: '雞腿便當',
        timeLabel: '12:00',
        qualityTag: '手動',
        dishes: const [],
        kcal: 780,
        proteinGrams: 35,
        carbGrams: 95,
        fatGrams: 28,
        fibreGrams: 5,
      ),
      eatenAt: today,
    );
    await pumpScreen(tester, const DailyNutritionScreen(), store: store);
    await _tapText(tester, '雞腿便當');
    await tester.pumpAndSettle();

    final detail = find.byType(MealDetailScreen);
    expect(detail, findsOneWidget);
    expect(
      find.descendant(of: detail, matching: find.byType(TextField)),
      findsNothing,
      reason: 'nothing to edit on the page itself',
    );
    expect(find.text('35 g'), findsOneWidget);
    // The energy each carries: 4 kcal a gram for carbohydrate less its
    // fibre and for protein, 9 for fat, 2 for the fibre itself.
    expect(find.text('95 g'), findsOneWidget, reason: 'as the label has it');
    expect(
      tester.getTopLeft(find.text('95 g')).dx,
      tester.getTopLeft(find.text(testL10n.macroCarb).last).dx,
      reason: 'the figures line up with the name, not its dot',
    );
    expect(
      tester.getTopLeft(find.text('5 g · 10 kcal')).dx,
      tester.getTopLeft(find.text(testL10n.macroFibre).last).dx,
    );
    expect(find.text('360 kcal'), findsOneWidget);
    expect(find.text('140 kcal'), findsOneWidget);
    expect(find.text('252 kcal'), findsOneWidget);
    expect(find.text('5 g · 10 kcal'), findsOneWidget);
    for (final nutrient in [Nutrient.polyols, Nutrient.alcohol]) {
      expect(
        find.text(nutrient.labelIn(testL10n)),
        findsOneWidget,
        reason: 'shown whether or not the meal has it on record',
      );
    }
    expect(
      find.text('0 g · 0 kcal'),
      findsNWidgets(2),
      reason: 'none on record reads as none',
    );
    expect(find.textContaining('%'), findsNothing);

    await tester.tap(find.bySemanticsLabel('編輯這一餐'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(FoodEditScreen),
        matching: find.text('編輯這一餐'),
      ),
      findsWidgets,
      reason: 'the form foods are added with, for this meal',
    );
    await disposeTree(tester);
  });

  testWidgets('a drink shows its alcohol, filled in from its strength', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final beer = store.backend.nutrition.logMeal(
      MealEvent(
        id: 'beer',
        name: '啤酒',
        timeLabel: '21:00',
        qualityTag: '手動',
        dishes: const [],
        kcal: 142,
        carbGrams: 12,
        proteinGrams: 1,
        fatGrams: 0,
        millilitres: 330,
        kind: ConsumptionKind.beverage,
      ),
      eatenAt: store.now(),
    );
    await _openFromHost(tester, FoodEditScreen(meal: beer), store);

    final scroll = find
        .descendant(
          of: find.byType(FoodEditScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(find.text('酒精度'), 200, scrollable: scroll);
    await _enterBeside(tester, '酒精度', '5');
    final alcohol = find.descendant(
      of: find
          .ancestor(of: find.text('酒精').first, matching: find.byType(Row))
          .first,
      matching: find.byType(TextField),
    );
    expect(
      tester.widget<TextField>(alcohol).controller!.text,
      '13',
      reason: '330 mL at 5 % is 16.5 mL, 13 g',
    );
    await _tapText(tester, '儲存');
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await pumpScreen(
      tester,
      MealDetailScreen(meal: store.backend.nutrition.mealById('beer')!),
      store: store,
    );
    expect(find.text('13 g · 91 kcal'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('an item of a meal is corrected, and the meal follows', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final nutrition = store.backend.nutrition;
    final today = store.now();
    nutrition.deleteMeals([
      for (final meal in nutrition.mealsOn(today)) meal.id,
    ]);
    nutrition.groupMeals([
      for (final (name, kcal) in [('蛋餅', 250.0), ('冰奶茶', 300.0)])
        nutrition.logMeal(
          MealEvent(
            id: name,
            name: name,
            timeLabel: '08:00',
            qualityTag: '手動',
            dishes: const [],
            kcal: kcal,
          ),
          eatenAt: today,
        ),
    ]);
    await pumpScreen(tester, const DailyNutritionScreen(), store: store);
    await tester.scrollUntilVisible(
      find.text('冰奶茶'),
      200,
      scrollable: _pageScroll,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('冰奶茶')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    expect(find.text('蛋餅、冰奶茶'), findsOneWidget);

    await tester.tap(find.text('冰奶茶'));
    await tester.pumpAndSettle();
    expect(find.byType(MealDetailScreen), findsOneWidget);
    expect(
      find.byType(FoodEditScreen),
      findsNothing,
      reason: 'an item opens to what it was; changing it is the pencil',
    );
    await tester.tap(find.bySemanticsLabel('編輯這一餐'));
    await tester.pumpAndSettle();
    // The day's page stays under the editor, so its 熱量 is left alone.
    await tester.enterText(
      find.descendant(
        of: find
            .ancestor(
              of: find.descendant(
                of: find.byType(FoodEditScreen),
                matching: find.text('kcal'),
              ),
              matching: find.byType(Row),
            )
            .first,
        matching: find.byType(TextField),
      ),
      '200',
    );
    await tester.pump();
    await _tapText(tester, '儲存');
    await tester.pumpAndSettle();
    expect(mealKcalOf(mealsOf(nutrition.mealsOn(today)).single), 450);
    expect(
      find.byType(MealDetailScreen),
      findsOneWidget,
      reason: 'saving returns to the meal',
    );
    Navigator.of(tester.element(find.byType(MealDetailScreen))).pop();
    await tester.pumpAndSettle();

    // The meal's own row opens to their sum, and takes it apart there.
    await Scrollable.ensureVisible(
      tester.element(find.text('蛋餅、冰奶茶')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('蛋餅、冰奶茶'));
    await tester.pumpAndSettle();
    final group = find.byType(MealGroupScreen);
    expect(group, findsOneWidget);
    expect(
      find.descendant(of: group, matching: find.text('450 kcal')),
      findsOneWidget,
      reason: 'the items summed',
    );
    expect(
      find.descendant(of: group, matching: find.text('2 項')),
      findsOneWidget,
    );

    // A name of its own, and blank goes back to its items.
    Future<void> rename(String name) async {
      await _tapText(tester, '重新命名');
      await tester.enterText(find.byType(TextField), name);
      await _tapText(tester, '儲存');
      await tester.pumpAndSettle();
    }

    await rename('週末早午餐');
    expect(
      find.descendant(of: group, matching: find.text('週末早午餐')),
      findsWidgets,
    );
    expect(
      nutrition.nameOfMeal(mealsOf(nutrition.mealsOn(today)).single),
      '週末早午餐',
    );
    await rename('');
    expect(
      find.descendant(of: group, matching: find.text('蛋餅、冰奶茶')),
      findsWidgets,
    );
    await _tapText(tester, '拆開這一餐');
    await tester.pumpAndSettle();
    expect(find.byType(MealChangePreviewScreen), findsOneWidget);
    expect(
      mealsOf(nutrition.mealsOn(today)),
      hasLength(1),
      reason: 'a preview splits nothing',
    );
    await _tapText(tester, '拆開');
    await tester.pumpAndSettle();
    expect(mealsOf(nutrition.mealsOn(today)), hasLength(2));
    expect(find.byType(MealGroupScreen), findsNothing, reason: 'nothing left');
    await disposeTree(tester);
  });

  testWidgets('a logged meal\'s brand is edited with the rest of it', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final nutrition = store.backend.nutrition;
    final meal = nutrition.logMeal(
      const MealEvent(
        id: 'soy',
        name: '無糖豆漿',
        timeLabel: '08:00',
        qualityTag: '手動',
        dishes: [],
        kcal: 140,
        brand: '統一',
      ),
      eatenAt: store.now(),
    );
    await _openFromHost(tester, FoodEditScreen(meal: meal), store);

    final brand = find.descendant(
      of: find.byType(FoodEditScreen),
      matching: find.widgetWithText(TextField, '統一'),
    );
    expect(brand, findsOneWidget, reason: 'the brand it was logged with');
    await tester.enterText(brand, '光泉');
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();
    expect(nutrition.mealById('soy')!.brand, '光泉');
    await disposeTree(tester);
  });

  testWidgets('a meal is starred from its page, as from its row', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final nutrition = store.backend.nutrition;
    final meal = nutrition.logMeal(
      const MealEvent(
        id: 'toast',
        name: '吐司',
        timeLabel: '08:00',
        qualityTag: '手動',
        dishes: [],
        kcal: 180,
      ),
      eatenAt: store.now(),
    );
    await _openFromHost(tester, MealDetailScreen(meal: meal), store);

    await tester.tap(find.bySemanticsLabel('加入收藏'));
    await tester.pumpAndSettle();
    expect(
      nutrition.mealById(meal.id)!.isFavorite,
      isTrue,
      reason: 'kept, not only on screen',
    );
    expect(find.bySemanticsLabel('取消收藏'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('取消收藏'));
    await tester.pumpAndSettle();
    expect(nutrition.mealById(meal.id)!.isFavorite, isFalse);
    expect(find.bySemanticsLabel('加入收藏'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('a logged meal is deleted from its page, undoably', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final nutrition = store.backend.nutrition;
    final meal = nutrition.logMeal(
      const MealEvent(
        id: 'toast',
        name: '吐司',
        timeLabel: '08:00',
        qualityTag: '手動',
        dishes: [],
        kcal: 180,
      ),
      eatenAt: store.now(),
    );
    final before = nutrition.mealsOn(store.now()).length;
    await _openFromHost(tester, MealDetailScreen(meal: meal), store);
    expect(find.text('編輯'), findsNothing, reason: 'the pencil alone');

    await tester.tap(find.bySemanticsLabel('刪除這一餐'));
    await tester.pumpAndSettle();
    expect(find.text('刪除「吐司」？'), findsOneWidget);
    expect(nutrition.mealsOn(store.now()), hasLength(before), reason: 'asks');
    await tester.tap(find.text('刪除這一餐'));
    // Not settled: the undo's countdown would run out.
    await tester.pump();
    await tester.pump(_pageTransition);
    expect(nutrition.mealsOn(store.now()), hasLength(before - 1));
    expect(find.byType(MealDetailScreen), findsNothing, reason: 'it left');

    await tester.tap(find.text('復原'));
    await tester.pump();
    expect(nutrition.mealsOn(store.now()), hasLength(before));
    await disposeTree(tester);
  });

  testWidgets('a meal\'s every nutrient is shown and corrected', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final nutrition = store.backend.nutrition;
    final meal = nutrition.logMeal(
      const MealEvent(
        id: 'shake',
        name: '乳清蛋白飲',
        timeLabel: '18:20',
        qualityTag: 'AI 估計',
        dishes: [],
        kcal: 186,
        nutrients: {Nutrient.sugar: 14.4, Nutrient.leucine: 1571},
      ),
      eatenAt: store.now(),
    );
    await _openFromHost(tester, FoodEditScreen(meal: meal), store);

    final editorScroll = find
        .descendant(
          of: find.byType(FoodEditScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('糖'),
      200,
      scrollable: editorScroll,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('糖')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    final sugar = find.descendant(
      of: find.ancestor(of: find.text('糖'), matching: find.byType(Row)).first,
      matching: find.byType(TextField),
    );
    expect(
      tester.widget<TextField>(sugar).controller!.text,
      '14.4',
      reason: 'a decimal kept as printed',
    );
    await tester.enterText(sugar, '12');
    await tester.scrollUntilVisible(
      find.text('白胺酸'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(FoodEditScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();

    final saved = nutrition
        .mealsOn(store.now())
        .firstWhere((logged) => logged.id == meal.id);
    expect(saved.nutrients[Nutrient.sugar], 12);
    expect(saved.nutrients[Nutrient.leucine], 1571, reason: 'kept as it was');
    await disposeTree(tester);
  });

  testWidgets('a meal moves to when it was eaten, and water stays water', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final clock = FakeClock();
    final store = AppStore(clock: clock.now, isOnboarded: true);
    final nutrition = store.backend.nutrition;
    final glass = nutrition.logWater(250);
    final viewModel = NutritionViewModel(store.backend);
    addTearDown(viewModel.dispose);

    final evening = clock.now().subtract(const Duration(days: 1));
    viewModel.retimeMeal(glass, evening);
    expect(
      nutrition.mealsOn(evening).map((meal) => meal.id),
      contains(glass.id),
    );
    expect(
      nutrition.mealsOn(clock.now()).map((meal) => meal.id),
      isNot(contains(glass.id)),
    );

    final moved = nutrition
        .mealsOn(evening)
        .firstWhere((meal) => meal.id == glass.id);
    await _openFromHost(tester, FoodEditScreen(meal: moved), store);
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(NumberFieldRow, '容量'),
        matching: find.byType(TextField),
      ),
      '300',
    );
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();
    final saved = nutrition
        .mealsOn(evening)
        .firstWhere((meal) => meal.id == glass.id);
    expect(saved.millilitres, 300);
    expect(saved.isWater, isTrue, reason: 'a corrected glass is still water');
    await disposeTree(tester);
  });

  testWidgets('a reference asks before leaving for its link', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const ReferencesScreen(), store: store);

    await tester.tap(find.textContaining('Mifflin, M. D.'));
    await tester.pumpAndSettle();
    expect(find.text('開啟連結'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.text('https://doi.org/10.1093/ajcn/51.2.241'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(AppDialog), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('relative load and RIR sources appear in training references', (
    tester,
  ) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const ReferencesScreen(), store: store);
    for (final (author, use, doi) in [
      (
        'American College of Sports Medicine. (2009).',
        '以 %1RM 表示訓練負荷',
        '10.1249/MSS.0b013e3181915670',
      ),
      ('Currier, B. S.', '以 %1RM 表示負荷的更新指引', '10.1249/MSS.0000000000003897'),
      ('Pelland, J. C.', '負荷與接近力竭程度是不同變數', '10.1007/s40279-022-01667-2'),
      // Pelland’s paper names Zourdos too, so this row needs its co-author.
      (
        'Zourdos, M. C., Klemp, A.',
        '以剩餘次數（RIR）表示接近力竭程度',
        '10.1519/JSC.0000000000001049',
      ),
    ]) {
      // 45 rows of a page this tall: a step has to cover the height of one.
      final citation = find.textContaining(author);
      await tester.scrollUntilVisible(
        citation,
        400,
        scrollable: _pageScroll,
        maxScrolls: 200,
      );
      // Centred first: a row caught at the bottom edge cannot be tapped.
      await Scrollable.ensureVisible(tester.element(citation), alignment: 0.5);
      await tester.pump();
      expect(citation, findsOneWidget);
      expect(find.text(use), findsOneWidget);
      await tester.tap(citation);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('https://doi.org/$doi'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('the week strip runs on past the screen\'s edges', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const DailyNutritionScreen(), store: store);

    // 19 September is a Saturday: its week is 14–20, and 13 belongs to
    // the week before, showing in the left margin.
    final monday = tester.getRect(find.bySemanticsLabel(RegExp('^9 月 14 日')));
    final before = tester.getRect(find.bySemanticsLabel(RegExp('^9 月 13 日')));
    expect(monday.left, closeTo(AppSpacing.screenGutter, 1));
    expect(before.right, closeTo(AppSpacing.screenGutter, 1));
    expect(before.left, lessThan(0), reason: 'cut off by the edge');
    await disposeTree(tester);
  });

  testWidgets('the day\'s cards keep one inset', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const DailyNutritionScreen(), store: store);

    double insetOf(Finder text) {
      final card = find.ancestor(of: text, matching: find.byType(AppCard));
      return tester.getTopLeft(text).dy - tester.getTopLeft(card.first).dy;
    }

    // The ring sits centred beside the macros, whose first line leads.
    final energy = insetOf(find.text(testL10n.macroCarb).first);
    final indicators = insetOf(find.text(testL10n.macroFibre));
    expect(
      (energy - indicators).abs(),
      lessThan(3),
      reason: 'a card\'s first line sits its inset from the top, not more',
    );
    expect(
      tester.getSize(find.widgetWithText(SectionLabel, testL10n.macroEnergy)),
      tester.getSize(find.widgetWithText(SectionLabel, '每日指標')),
      reason: 'the 變更 link does not push its card further down',
    );
    await disposeTree(tester);
  });

  testWidgets('losing fat is set as a share of body weight a week', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.journal
      ..setSex(Sex.female)
      ..setBirthYear(1996)
      ..recordBodyReadings({BodyMetric.height: 165});
    await pumpScreen(tester, const NutritionTargetScreen(), store: store);

    await _tapText(tester, '減脂');
    // The kg follows the latest weight the demo records hold.
    expect(find.textContaining('−0.5% · −'), findsOneWidget);
    await _tapText(tester, '每週變化');
    expect(
      find.textContaining('−0.75% · −', findRichText: true),
      findsOneWidget,
      reason: 'the rate as it is, not rounded to one place',
    );
    await tester.tap(find.textContaining('−0.25% · −', findRichText: true));
    await tester.pumpAndSettle();
    expect(store.backend.nutrition.targetSettings.weeklyPercent, -0.25);
    expect(find.text('維持熱量'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('a typed-in energy target keeps its decimals', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const NutritionTargetScreen(), store: store);

    await _tapText(tester, '自己設定');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '2150.5');
    await _tapText(tester, '儲存');
    await tester.pumpAndSettle();

    expect(store.backend.nutrition.targetSettings.customKcal, 2150.5);
    expect(
      find.textContaining('2,150.5'),
      findsWidgets,
      reason: 'the figure the user typed, not a rounded one',
    );

    // The macronutrients follow it, worked out to the tenth.
    await pumpScreen(tester, const DailyNutritionScreen(), store: store);
    expect(
      find.textContaining('59.7'),
      findsWidgets,
      reason: 'fat: 2150.5 kcal x 25 % / 9',
    );
    await disposeTree(tester);
  });

  testWidgets('water has a page of its own, apart from 飲食', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final today = store.now();
    store.backend.nutrition.deleteMeals([
      for (final meal in store.backend.nutrition.mealsOn(today)) meal.id,
    ]);
    store.backend.nutrition.logWater(250);
    store.backend.nutrition.logWater(250);
    await pumpScreen(tester, const DailyNutritionScreen(), store: store);

    await tester.scrollUntilVisible(
      find.text('這一天沒有記錄任何一餐'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('這一天沒有記錄任何一餐'), findsOneWidget);
    expect(find.textContaining('250 mL'), findsNothing, reason: 'not on 飲食');
    await disposeTree(tester);

    await pumpScreen(tester, const WaterScreen(), store: store);
    expect(
      find.text('500 / 1,500 mL', findRichText: true),
      findsOneWidget,
      reason: 'the day\'s water, against 國健署\'s reference',
    );
    expect(find.text('250 mL'), findsNWidgets(2), reason: 'each glass');
    await disposeTree(tester);
  });

  testWidgets('a glass of water is one tap and one kind of record', (
    tester,
  ) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const WaterScreen(), store: store);
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

  testWidgets('the day counts salt the way 我的 says, both labels in it', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final nutrition = store.backend.nutrition;
    final today = store.now();
    nutrition.deleteMeals([
      for (final meal in nutrition.mealsOn(today)) meal.id,
    ]);
    // A Taiwanese label's sodium and a Japanese label's salt.
    for (final (id, carb, fibre, nutrients) in [
      ('bento', 80.0, 5.0, {Nutrient.sodium: 1270.0}),
      ('onigiri', 40.0, 1.0, {Nutrient.saltEquivalent: 1.27}),
    ]) {
      nutrition.logMeal(
        MealEvent(
          id: id,
          name: id,
          timeLabel: '12:00',
          qualityTag: '手動',
          dishes: const [],
          kcal: 300,
          proteinGrams: 10,
          carbGrams: carb,
          fatGrams: 8,
          fibreGrams: fibre,
          nutrients: nutrients,
        ),
        eatenAt: today,
      );
    }

    await pumpScreen(tester, const DailyNutritionScreen(), store: store);
    expect(
      find.text('1,770 / 2,400 mg'),
      findsOneWidget,
      reason: '1.27 g of salt is 500 mg of sodium',
    );
    expect(find.text('推算'), findsOneWidget);
    expect(
      find.text(Nutrient.saltEquivalent.labelIn(testL10n)),
      findsNothing,
      reason: 'folded into sodium, not listed again',
    );

    await tester.pumpWidget(const SizedBox());
    await pumpScreen(tester, const MeScreen(), store: store);
    await _tapText(tester, '營養標示');
    await tester.pumpAndSettle();
    await _tapText(tester, '日本');
    await tester.pumpAndSettle();
    expect(nutrition.convention, NutritionConvention.japan);

    await tester.pumpWidget(const SizedBox());
    await pumpScreen(tester, const DailyNutritionScreen(), store: store);
    expect(
      find.text('4.5 / 6.5 g'),
      findsOneWidget,
      reason: 'salt, against the lower target while the sex is not set',
    );
    // Named as a Japanese label names them, with 糖質 in place of sugar.
    for (final name in ['熱量', 'たんぱく質', '炭水化物', '脂質', '食物繊維', '食塩相当量']) {
      expect(find.text(name), findsWidgets, reason: name);
    }
    expect(find.text('碳水化合物'), findsNothing);
    expect(find.text('糖質'), findsOneWidget);
    expect(find.text('114 g'), findsOneWidget, reason: '(80 − 5) + (40 − 1)');
    expect(find.text('推算'), findsNWidgets(2), reason: '糖質 and the salt');

    // The EU's way: salt in g against 5 g, and its carbohydrate without
    // the fibre.
    await tester.pumpWidget(const SizedBox());
    await pumpScreen(tester, const MeScreen(), store: store);
    await _tapText(tester, '營養標示');
    await tester.pumpAndSettle();
    await _tapText(tester, '歐盟');
    await tester.pumpAndSettle();
    expect(nutrition.convention, NutritionConvention.europeanUnion);
    await tester.pumpWidget(const SizedBox());
    await pumpScreen(tester, const DailyNutritionScreen(), store: store);
    expect(find.text('4.5 / 5 g'), findsOneWidget);
    expect(find.text('Salt'), findsOneWidget);
    expect(find.text('Carbohydrate'), findsWidgets);
    expect(
      find.textContaining(RegExp(r'^114( / \d+)? g$')),
      findsOneWidget,
      reason: 'the carbohydrate less its fibre',
    );
    await disposeTree(tester);
  });

  testWidgets('a Japanese drink reads as its Japanese label', (tester) async {
    usePhoneViewport(tester);
    final coffee = parseCatalogue(
      jsonDecode(
        File('assets/catalogue/7eleven-sevencafe-jp.json').readAsStringSync(),
      ) as Map<String, dynamic>,
    ).firstWhere((food) => food.sizeName == 'R');
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, PortionScreen(food: coffee), store: store);

    for (final (label, value) in [
      ('たんぱく質', '0.4 g'),
      ('脂質', '0 g'),
      ('炭水化物', '1.3 g'),
      ('糖質', '1.1 g'),
      ('食物繊維', '0.2 g'),
      ('食塩相当量', '0.01 g'),
    ]) {
      expect(find.text(label), findsOneWidget);
      expect(find.text(value), findsWidgets, reason: label);
    }
    // As printed; then, apart from the label, its salt as a Taiwanese
    // day counts it, marked as worked out.
    expect(find.text('鈉'), findsOneWidget);
    expect(find.textContaining('mg · 推算'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    store.backend.nutrition.setConvention(NutritionConvention.japan);
    await pumpScreen(tester, PortionScreen(food: coffee), store: store);
    expect(
      find.text('鈉'),
      findsNothing,
      reason: 'a Japanese reading needs nothing past the label',
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
    await pumpScreen(tester, FoodEditScreen(meal: logged), store: store);

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

/// A photo's text, one printed row per line, stacked down the page.
class _Lines implements LabelReader {
  _Lines(this.rows);

  final List<String> rows;

  @override
  Future<List<TextLine>> readText(String imagePath) async => [
    for (final (index, row) in rows.indexed)
      TextLine(text: row, left: 0, top: index * 40.0, width: 200, height: 30),
  ];
}

/// The sleep trend read night by night over the last week.
Future<void> _openSleepWeek(WidgetTester tester, AppStore store) async {
  await pumpScreen(
    tester,
    const TrendDetailScreen(domain: TrendDomain.sleep),
    store: store,
  );
  await tester.tap(find.text('週'));
  await tester.pumpAndSettle();
}
