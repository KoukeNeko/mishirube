import 'package:flutter/material.dart'
    show CustomScrollView, Icons, Scaffold, StatefulBuilder;
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter/services.dart' show MethodChannel, SystemChannels;
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/engines/set_schemes.dart';
import 'package:mishirube/backend/engines/training_metrics.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/training/set_load_table.dart';
import 'package:mishirube/features/training/workout_summary_screen.dart';
import 'package:mishirube/l10n/l10n.dart';
import 'package:mishirube/shared/format.dart';
import 'package:mishirube/shared/widgets/widgets.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/features/today/today_screen.dart';
import 'package:mishirube/features/training/active_workout_screen.dart';

import '../../support/harness.dart';

void main() {
  AppStore newStore(FakeClock clock) =>
      AppStore(clock: clock.now, isOnboarded: true);

  /// What the page asks the device to do: the kind of each vibration, and
  /// each call to the rest notice's channel (`cue` among them).
  ({List<String> haptics, List<String> notice}) listenToDevice(
    WidgetTester tester,
  ) {
    final haptics = <String>[];
    final notice = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String);
      }
      return null;
    });
    const channel = MethodChannel('mishirube/rest_notice');
    messenger.setMockMethodCallHandler(channel, (call) async {
      notice.add(call.method);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(channel, null);
    });
    return (haptics: haptics, notice: notice);
  }

  Finder inDialog(Finder finder) =>
      find.descendant(of: find.byType(AppDialog), matching: finder);

  group('a scheduled workout', () {
    testWidgets('can be cancelled, not ended', (tester) async {
      usePhoneViewport(tester);
      final store = newStore(FakeClock())..startWorkout();
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);

      expect(find.text('結束'), findsNothing);
      expect(find.text('暫停'), findsNothing);
      expect(find.textContaining('已安排'), findsOneWidget, reason: 'the status');

      await tester.tap(find.text('取消安排'));
      await tester.pumpAndSettle();
      expect(find.text('取消這次訓練？'), findsOneWidget);

      await tester.tap(find.text('保留'));
      await tester.pumpAndSettle();
      expect(store.activeWorkout, isNotNull, reason: 'kept');

      await tester.tap(find.text('取消安排'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消訓練'));
      await tester.pumpAndSettle();
      expect(store.activeWorkout, isNull);
      await disposeTree(tester);
    });

    testWidgets('waits on Today, and starts from there', (tester) async {
      usePhoneViewport(tester);
      final store = newStore(FakeClock())..startWorkout();
      await pumpScreen(tester, const TodayScreen(), store: store);

      expect(find.text('已安排'), findsOneWidget);
      expect(find.text('訓練進行中'), findsNothing);
      expect(find.text('回到訓練'), findsNothing);
      expect(find.text(store.activeWorkout!.routineName), findsOneWidget);

      await tester.tap(find.text('開始運動'));
      await tester.pumpAndSettle();
      expect(store.activeWorkout!.isReady, isFalse);
      expect(find.byType(ActiveWorkoutScreen), findsOneWidget);
      expect(find.text('暫停'), findsOneWidget);
      expect(find.text('結束'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('is only looked over from Today, not begun', (tester) async {
      usePhoneViewport(tester);
      final store = newStore(FakeClock())..startWorkout();
      await pumpScreen(tester, const TodayScreen(), store: store);

      await tester.tap(find.text('查看'));
      await tester.pumpAndSettle();
      expect(find.byType(ActiveWorkoutScreen), findsOneWidget);
      expect(store.activeWorkout!.isReady, isTrue);
      await disposeTree(tester);
    });
  });

  group('a set number', () {
    testWidgets('is a button that opens the set, at 44 points', (tester) async {
      usePhoneViewport(tester);
      final semantics = tester.ensureSemantics();
      final store = newStore(FakeClock())
        ..startWorkout()
        ..beginWorkout();
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);

      final button = find.bySemanticsLabel('編輯第 1 組').first;
      expect(
        tester.getSemantics(button),
        matchesSemantics(label: '編輯第 1 組', isButton: true, hasTapAction: true),
      );
      final size = tester.getSize(button);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('刪除這一組'), findsOneWidget, reason: 'the set editor');
      semantics.dispose();
      await disposeTree(tester);
    });

    testWidgets('survives large text', (tester) async {
      usePhoneViewport(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = newStore(FakeClock())
        ..startWorkout()
        ..beginWorkout();
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);

      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });
  });

  group('quick fill', () {
    testWidgets('sets the working sets from a scheme, keeping done ones', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final store = newStore(FakeClock())
        ..startWorkout()
        ..beginWorkout()
        ..completeNextSet();
      final first = store.activeWorkout!.exercises.first.sets.first;
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);

      await tester.tap(find.text('快速填入').first);
      await tester.pumpAndSettle();
      expect(find.text('基礎'), findsOneWidget);
      expect(find.text('逐漸加重'), findsOneWidget);
      expect(find.text('每組同重量'), findsOneWidget, reason: 'what it does');

      await tester.tap(find.text('5×5 力量'));
      await tester.pumpAndSettle();
      expect(find.text('5 組 5 下同重量'), findsOneWidget);
      // The first set is done, so the four after it are listed.
      expect(find.text('第 5 組'), findsOneWidget);
      expect(find.text('第 1 組'), findsNothing);

      await tester.tap(find.text('套用'));
      await tester.pumpAndSettle();

      final sets = store.activeWorkout!.exercises.first.sets;
      expect(sets, hasLength(5));
      expect(sets.first, same(first));
      expect(sets.first.isDone, isTrue);
      expect([for (final set in sets.skip(1)) set.reps], everyElement(5));
      expect(
        {for (final set in sets.skip(1)) set.weightKg},
        hasLength(1),
        reason: 'one weight for every set',
      );
      await disposeTree(tester);
    });

    testWidgets('starts from the heaviest of the last 90 days, and says so', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final store = newStore(FakeClock())
        ..startWorkout()
        ..beginWorkout();
      final squat = store.activeWorkout!.exercises.first.exercise;
      final source = mainWeightFrom(store.exerciseHistory(squat), store.now())!;
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);

      await tester.tap(find.text('快速填入').first);
      await tester.pumpAndSettle();

      expect(find.text(source.isRecent ? '近 90 天最高' : '歷史最高'), findsOneWidget);
      expect(find.text(formatWeight(source.kg)), findsOneWidget);

      await tester.tap(find.byTooltip('增加 2.5 kg'));
      await tester.pump();
      expect(find.text(formatWeight(source.kg + plateStepKg)), findsOneWidget);
      await disposeTree(tester);
    });
  });

  group('load', () {
    testWidgets('shows the latest session, and an earlier one at a step', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final store = newStore(FakeClock())
        ..startWorkout()
        ..beginWorkout();
      final squat = store.activeWorkout!.exercises.first.exercise;
      final sessions = store.sessionsOf(squat);
      expect(sessions.length, greaterThan(1));
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);
      String day(int index) {
        final date = sessions[index].date;
        final now = store.now();
        final days = DateTime.utc(
          now.year,
          now.month,
          now.day,
        ).difference(DateTime.utc(date.year, date.month, date.day)).inDays;
        return '${AppDates.of(testL10n).fullDate(date)} · '
            '${days == 0 ? testL10n.tabToday : testL10n.daysAgo(count: days)}';
      }

      await tester.tap(find.text('載入').first);
      await tester.pumpAndSettle();
      expect(find.text('${squat.name} 紀錄'), findsOneWidget);
      expect(find.text(day(0)), findsOneWidget, reason: 'the latest first');
      expect(find.text('訓練量'), findsOneWidget);
      expect(find.byTooltip('較新的紀錄').hitTestable(), findsOneWidget);

      await tester.tap(find.byTooltip('較早的紀錄'));
      await tester.pump();
      expect(find.text(day(1)), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(PrimaryButton),
          matching: find.text('載入'),
        ),
      );
      await tester.pumpAndSettle();

      final working = [
        for (final set in sessions[1].sets)
          if (set.type == SetType.working) (set.weightKg, set.reps),
      ];
      expect([
        for (final set in store.activeWorkout!.exercises.first.sets)
          if (set.type == SetType.working) (set.weightKg, set.reps),
      ], working);
      await disposeTree(tester);
    });

    testWidgets('an exercise never done has nothing to load', (tester) async {
      usePhoneViewport(tester);
      final never = newStore(FakeClock()).exercises
          .firstWhere((exercise) => exercise.recordCount == 0);
      final store = newStore(FakeClock())
        ..startFreeWorkout([never])
        ..beginWorkout();
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);

      await tester.tap(find.text('載入').first);
      await tester.pumpAndSettle();
      expect(find.text('沒有紀錄'), findsOneWidget);
      expect(
        tester
            .widget<PrimaryButton>(find.widgetWithText(PrimaryButton, '載入'))
            .onPressed,
        isNull,
      );
      await disposeTree(tester);
    });
  });

  testWidgets('the sheets keep their button on screen at 2x text', (
    tester,
  ) async {
    usePhoneViewport(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = newStore(FakeClock())
      ..startWorkout()
      ..beginWorkout();
    await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);

    for (final (chip, button) in [('快速填入', '套用'), ('載入', '載入')]) {
      await tester.tap(find.text(chip).first);
      await tester.pumpAndSettle();
      final target = find.widgetWithText(PrimaryButton, button);
      expect(target.hitTestable(), findsOneWidget, reason: '$chip: $button');
      expect(tester.takeException(), isNull, reason: chip);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(target, findsNothing, reason: 'dismissed');
    }
    await disposeTree(tester);
  });

  group('the watch heart rate', () {
    testWidgets('shows beside the clock while recent, then goes', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final clock = FakeClock();
      final store = newStore(clock)
        ..startWorkout()
        ..beginWorkout();
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);
      expect(find.byIcon(Icons.favorite), findsNothing);

      store.takeHeartRate(142, clock.now());
      clock.advance(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('142'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      clock.advance(AppStore.liveHeartRateMaxAge);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('142'), findsNothing);
      expect(find.byIcon(Icons.favorite), findsNothing);
    });
  });

  group('the workout clock', () {
    testWidgets('is corrected from its dialog, and paused there', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final clock = FakeClock();
      final store = newStore(clock)
        ..startWorkout()
        ..beginWorkout();
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);
      clock.advance(const Duration(minutes: 10));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('時間'));
      await tester.pumpAndSettle();
      expect(find.text('運動時間'), findsOneWidget);
      expect(inDialog(find.text('10:00')), findsOneWidget);

      await tester.tap(find.text('+1 分'));
      await tester.pump();
      expect(inDialog(find.text('11:00')), findsOneWidget);
      await tester.tap(find.text('+5 分'));
      await tester.pump();
      expect(inDialog(find.text('16:00')), findsOneWidget);

      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('−5 分'));
        await tester.pump();
      }
      expect(
        inDialog(find.text('0:00')),
        findsOneWidget,
        reason: 'never below',
      );

      await tester.tap(inDialog(find.text('暫停')));
      await tester.pump();
      expect(store.activeWorkout!.isPaused, isTrue);
      expect(inDialog(find.text('繼續')), findsOneWidget);

      await tester.tap(inDialog(find.text('完成')));
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('a rest tucks into one line as the page scrolls down', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final semantics = tester.ensureSemantics();
      final store = newStore(FakeClock())
        ..startWorkout()
        ..beginWorkout();
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);
      await tester.tap(find.bySemanticsLabel(RegExp('^第 1 組完成')).first);
      await tester.pump();
      expect(find.text('+15 秒'), findsOneWidget);

      final page = find.byType(CustomScrollView).first;
      await tester.drag(page, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('+15 秒'), findsNothing, reason: 'tucked away');
      expect(find.text('跳過休息'), findsOneWidget, reason: 'still a tap away');

      await tester.drag(page, const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(
        find.text('+15 秒'),
        findsOneWidget,
        reason: 'back on scrolling up',
      );
      semantics.dispose();
      await disposeTree(tester);
    });

    testWidgets('a rest shows the next set, and counts the time past its end '
        'until it is closed', (tester) async {
      usePhoneViewport(tester);
      final semantics = tester.ensureSemantics();
      final device = listenToDevice(tester);
      final clock = FakeClock();
      final store = newStore(clock)
        ..startWorkout()
        ..beginWorkout();
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);
      await tester.tap(find.bySemanticsLabel(RegExp('^第 1 組完成')).first);
      await tester.pump();
      expect(find.textContaining('下一組 · 槓鈴深蹲 · '), findsOneWidget);
      device.haptics.clear();

      clock.advance(store.restLength + const Duration(seconds: 12));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('+0:12'), findsOneWidget);
      expect(find.text('+15 秒'), findsNothing, reason: 'nothing to lengthen');
      expect(
        tester.widget<ProgressLine>(find.byType(ProgressLine).last).progress,
        1,
      );
      expect(device.haptics, ['HapticFeedbackType.heavyImpact']);
      expect(device.notice.where((call) => call == 'cue'), hasLength(1));

      clock.advance(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('+0:15'), findsOneWidget);
      expect(device.haptics, hasLength(1), reason: 'once, at the end');

      await tester.tap(find.text('關閉').last);
      await tester.pump();
      expect(store.isResting, isFalse);
      semantics.dispose();
      await disposeTree(tester);
    });

    testWidgets('a rest is cut or lengthened at the foot, never below 0', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final semantics = tester.ensureSemantics();
      final clock = FakeClock();
      final store = newStore(clock)
        ..startWorkout()
        ..beginWorkout();
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);
      await tester.tap(find.bySemanticsLabel(RegExp('^第 1 組完成')).first);
      await tester.pump();
      final endsAt = store.restEndsAt!;

      await tester.tap(find.text('+15 秒'));
      await tester.pump();
      expect(store.restEndsAt, endsAt.add(const Duration(seconds: 15)));
      await tester.tap(find.text('−15 秒'));
      await tester.pump();
      expect(store.restEndsAt, endsAt);

      clock.advance(store.restLength - const Duration(seconds: 10));
      await tester.tap(find.text('−15 秒'));
      await tester.pump();
      expect(store.restEndsAt, isNull, reason: '10 s left less 15 is over');
      expect(find.text('跳過休息'), findsNothing);
      semantics.dispose();
      await disposeTree(tester);
    });

    testWidgets('the foot survives large text with a rest running', (
      tester,
    ) async {
      usePhoneViewport(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = newStore(FakeClock())
        ..startWorkout()
        ..beginWorkout()
        ..logNextSet();
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);

      expect(store.restEndsAt, isNotNull);
      expect(find.text('+30 秒').hitTestable(), findsOneWidget);
      expect(find.text('完成訓練').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('the rest of an exercise and automatic rest are set there', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final semantics = tester.ensureSemantics();
      final store = newStore(FakeClock())
        ..startWorkout()
        ..beginWorkout();
      final squat = store.activeWorkout!.exercises.first.exercise;
      final usual = store.restFor(squat);
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);
      await tester.tap(find.bySemanticsLabel(RegExp('^第 1 組完成')).first);
      await tester.pump();

      await tester.tap(find.text('休息'));
      await tester.pumpAndSettle();
      expect(find.text('休息時間'), findsOneWidget);
      expect(inDialog(find.text(squat.name)), findsOneWidget);
      expect(inDialog(find.text('2:00')), findsOneWidget);

      await tester.tap(find.byTooltip('增加 15 秒'));
      await tester.pump();
      expect(store.restFor(squat), usual + const Duration(seconds: 15));
      expect(inDialog(find.text('2:15')), findsOneWidget);
      await tester.tap(find.byTooltip('減少 15 秒'));
      await tester.pump();
      await tester.tap(find.byTooltip('減少 15 秒'));
      await tester.pump();
      expect(inDialog(find.text('1:45')), findsOneWidget);

      await tester.tap(find.text('完成一組後自動開始休息'));
      await tester.pump();
      expect(store.isAutoRest, isFalse);
      await tester.tap(inDialog(find.text('完成')));
      await tester.pumpAndSettle();

      store.skipRest();
      await tester.pump();
      await tester.tap(find.bySemanticsLabel(RegExp('^第 2 組完成')).first);
      await tester.pump();
      expect(store.restEndsAt, isNull, reason: 'no rest by itself');
      expect(find.text('跳過休息'), findsNothing);
      semantics.dispose();
      await disposeTree(tester);
    });
  });

  group('a timed exercise', () {
    ExerciseDefinition plank(AppStore store) =>
        store.exercises.firstWhere((exercise) => exercise.id == 'plank');

    testWidgets('has a time to fill in, not kg and reps', (tester) async {
      usePhoneViewport(tester);
      final store = newStore(FakeClock());
      store
        ..startFreeWorkout([plank(store)])
        ..beginWorkout();
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);

      expect(find.text('時間'), findsWidgets, reason: 'the column');
      expect(find.text('kg'), findsNothing);
      expect(find.text('次'), findsNothing);
      expect(find.text('0:30'), findsWidgets, reason: 'what is planned');
      expect(
        find.textContaining('0 kg'),
        findsNothing,
        reason: 'no volume for a time',
      );
      expect(find.text('總時間 0:00'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('counts its time down from its button, locked as it runs, '
        'and logs the time held when ended early', (tester) async {
      usePhoneViewport(tester);
      final semantics = tester.ensureSemantics();
      final clock = FakeClock();
      final store = newStore(clock);
      store
        ..startFreeWorkout([plank(store)])
        ..beginWorkout();
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);

      await tester.tap(find.byTooltip('開始計時').first);
      await tester.pump();
      expect(store.setTimer, isNotNull);
      clock.advance(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.text('0:20'),
        findsOneWidget,
        reason: '30 s planned, 10 gone',
      );
      final bar = tester.widget<ProgressLine>(find.byType(ProgressLine));
      expect(bar.progress, closeTo(1 / 3, 0.01));
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(RegExp('^編輯第 1 組')))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isFalse,
        reason: 'a set under way keeps what it was started with',
      );

      // Leaving and coming back keeps the timer: it is not the page's.
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);
      expect(store.setTimer, isNotNull);

      clock.advance(const Duration(seconds: 5));
      await tester.tap(find.bySemanticsLabel(RegExp('^第 1 組完成')).first);
      await tester.pump();
      final set = store.activeWorkout!.exercises.first.sets.first;
      expect(set.isDone, isTrue);
      expect(set.durationSeconds, 15);
      expect(store.setTimer, isNull);
      expect(store.restEndsAt, isNotNull, reason: 'the rest starts');
      expect(find.text('總時間 0:15'), findsOneWidget);
      semantics.dispose();
      await disposeTree(tester);
    });

    testWidgets('is done by itself once its time runs out', (tester) async {
      usePhoneViewport(tester);
      final clock = FakeClock();
      final store = newStore(clock);
      store
        ..startFreeWorkout([plank(store)])
        ..beginWorkout();
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);

      await tester.tap(find.byTooltip('開始計時').first);
      await tester.pump();
      clock.advance(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 1));
      final set = store.activeWorkout!.exercises.first.sets.first;
      expect(set.isDone, isTrue);
      expect(set.durationSeconds, 30);
      expect(store.setTimer, isNull);
      expect(store.restEndsAt, isNotNull, reason: 'the rest starts');
      await disposeTree(tester);
    });

    testWidgets('counts the last three seconds down, then ends with a cue', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final device = listenToDevice(tester);
      final clock = FakeClock();
      final store = newStore(clock);
      store
        ..startFreeWorkout([plank(store)])
        ..beginWorkout();
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);

      await tester.tap(find.byTooltip('開始計時').first);
      await tester.pump();
      device.haptics.clear();
      device.notice.clear();
      for (var second = 1; second < 30; second++) {
        clock.advance(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
      expect(
        device.haptics,
        List.filled(3, 'HapticFeedbackType.lightImpact'),
        reason: 'at 3, 2 and 1 s left',
      );
      expect(device.notice.where((call) => call == 'cue'), hasLength(3));

      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(device.haptics.last, 'HapticFeedbackType.heavyImpact');
      expect(device.haptics, hasLength(4));
      expect(device.notice.where((call) => call == 'cue'), hasLength(4));
      await disposeTree(tester);
    });

    testWidgets('makes no sound with the cue off, and nothing under five '
        'seconds counts down', (tester) async {
      usePhoneViewport(tester);
      final device = listenToDevice(tester);
      final clock = FakeClock();
      final store = newStore(clock)..setCueSound(false);
      store
        ..startFreeWorkout([plank(store)])
        ..beginWorkout();
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);

      await tester.tap(find.byTooltip('開始計時').first);
      await tester.pump();
      device.haptics.clear();
      clock.advance(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 1));
      expect(device.haptics, ['HapticFeedbackType.heavyImpact']);
      expect(device.notice, isNot(contains('cue')));
      await disposeTree(tester);
    });

    testWidgets('a longer hold than any before is a record, and a total', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final clock = FakeClock();
      final store = newStore(clock);
      final exercise = plank(store);
      store
        ..startFreeWorkout([exercise])
        ..beginWorkout()
        ..completeNextSet();
      clock.advance(const Duration(minutes: 3));
      store.finishWorkout();
      clock.advance(const Duration(days: 1));

      store
        ..startFreeWorkout([exercise])
        ..beginWorkout()
        ..editSet(0, weightKg: 0, reps: 0, rir: null, seconds: 50)
        ..toggleSet(0);
      expect(
        store.isPersonalRecord(
          exercise,
          WorkoutSet(
            weightKg: 0,
            reps: 0,
            previousWeightKg: 0,
            previousReps: 0,
            durationSeconds: 20,
            isDone: true,
          ),
        ),
        isFalse,
        reason: 'shorter than the 0:30 before',
      );
      clock.advance(const Duration(minutes: 3));
      store.finishWorkout();

      final review = store.workoutReview(store.lastFinishedWorkout!);
      expect(review.records, 1, reason: 'longer than 0:30');
      expect(review.volumeKg, 0);
      expect(review.seconds, 50);

      await pumpScreen(
        tester,
        WorkoutSummaryScreen(workoutId: store.lastFinishedWorkout!.id),
        store: store,
      );
      expect(find.text('總時間'), findsOneWidget);
      expect(find.text('0:50'), findsWidgets);
      expect(find.text('總量'), findsNothing, reason: 'no kg for a plank');
      await disposeTree(tester);
    });

    testWidgets('is edited by its time, with no reps in reserve', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final semantics = tester.ensureSemantics();
      final store = newStore(FakeClock());
      store
        ..startFreeWorkout([plank(store)])
        ..beginWorkout();
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);

      await tester.tap(find.bySemanticsLabel('編輯第 1 組').first);
      await tester.pumpAndSettle();
      expect(find.text('RIR'), findsNothing);
      expect(find.text('kg'), findsNothing);
      await tester.tap(find.byTooltip('增加 5 秒'));
      await tester.pump();
      await tester.tap(inDialog(find.text('儲存')));
      await tester.pumpAndSettle();
      expect(
        store.activeWorkout!.exercises.first.sets.first.durationSeconds,
        35,
      );

      // Its time field opens minutes and seconds.
      await tester.tap(find.bySemanticsLabel('第 1 組時間').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('增加 1 分'));
      await tester.pump();
      await tester.tap(find.byTooltip('減少 5 秒'));
      await tester.pump();
      await tester.tap(inDialog(find.text('儲存')));
      await tester.pumpAndSettle();
      expect(
        store.activeWorkout!.exercises.first.sets.first.durationSeconds,
        90,
        reason: '0:35 + 1 min − 5 s',
      );
      semantics.dispose();
      await disposeTree(tester);
    });

    testWidgets('has only the basic scheme, and sets its time', (tester) async {
      usePhoneViewport(tester);
      final store = newStore(FakeClock());
      store
        ..startFreeWorkout([plank(store)])
        ..beginWorkout();
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);

      await tester.tap(find.text('快速填入').first);
      await tester.pumpAndSettle();
      expect(find.text('逐漸加重'), findsNothing);
      expect(find.text('主要重量'), findsNothing);
      expect(find.text('次數'), findsNothing);
      await tester.tap(find.byTooltip('增加 5 秒'));
      await tester.tap(find.byTooltip('多 1 組'));
      await tester.pump();
      await tester.tap(find.text('套用'));
      await tester.pumpAndSettle();

      final sets = store.activeWorkout!.exercises.first.sets;
      expect(sets, hasLength(4));
      expect({for (final set in sets) set.durationSeconds}, {35});
      await disposeTree(tester);
    });

    testWidgets('a weighted hold has weight and time, a run distance', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final store = newStore(FakeClock());
      ExerciseDefinition make(String id, TrackingType type) {
        final exercise = ExerciseDefinition(
          id: id,
          name: id,
          equipment: Equipment.bodyweight,
          primaryMuscles: const [MuscleGroup.core],
          pattern: MovementPattern.isolation,
          trackingType: type,
        );
        store.backend.storage.exercises.save(exercise);
        return exercise;
      }

      final hold = make('weighted-hold', TrackingType.weightDuration);
      final run = make('run-intervals', TrackingType.distance);
      final pushups = make('push-ups', TrackingType.reps);
      store
        ..startFreeWorkout([hold, run, pushups])
        ..beginWorkout();
      await pumpScreen(tester, const ActiveWorkoutScreen(), store: store);

      expect(find.text('kg'), findsOneWidget, reason: 'the weighted hold');
      expect(find.text('km'), findsOneWidget, reason: 'the run');
      expect(
        find.text('時間'),
        findsNWidgets(3),
        reason: 'the hold, the run, and the clock at the foot',
      );
      await tester.dragUntilVisible(
        find.text('push-ups'),
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );
      expect(find.text('次'), findsOneWidget, reason: 'push-ups only');
      expect(find.byTooltip('開始計時'), findsNWidgets(3), reason: 'the hold');
      expect(find.textContaining('總距離'), findsOneWidget);
      expect(find.textContaining('總次數'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });
  });

  group('a plan of timed sets', () {
    testWidgets('is a table of times, changed in the time dialog', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final semantics = tester.ensureSemantics();
      var loads = [const SetLoad(seconds: 30), const SetLoad(seconds: 45)];
      await pumpScreen(
        tester,
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ExerciseLoadsCard(
              name: '棒式',
              trackingType: TrackingType.duration,
              loads: loads,
              onLoads: (next) => setState(() => loads = next),
              onRemove: () {},
            ),
          ),
        ),
        store: newStore(FakeClock()),
      );

      expect(find.text('時間'), findsOneWidget);
      expect(find.text('kg'), findsNothing);
      expect(find.text('0:30'), findsOneWidget);
      expect(find.text('0:45'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('第 2 組時間'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('增加 5 秒'));
      await tester.pump();
      await tester.tap(inDialog(find.text('儲存')));
      await tester.pumpAndSettle();
      expect(loads, [const SetLoad(seconds: 30), const SetLoad(seconds: 50)]);
      expect(find.text('0:50'), findsOneWidget);

      await tester.tap(find.text('新增組'));
      await tester.pump();
      expect(
        loads.last,
        const SetLoad(seconds: 50),
        reason: 'repeats the last',
      );
      semantics.dispose();
      await disposeTree(tester);
    });
  });
}
