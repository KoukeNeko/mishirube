import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/engines/program_generator.dart';
import 'package:mishirube/backend/seed/exercise_catalogue.dart';
import 'package:mishirube/backend/seed/seed.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/training/training_screen.dart';

import '../../support/harness.dart';

/// Tall enough to build every workout of a program at once.
const tallPhone = WindowCase(
  'tall phone',
  Size(390, 4000),
  padding: FakeViewPadding(top: phoneTopInset, bottom: phoneBottomInset),
);

void main() {
  /// A store holding the whole library and the demo workouts, so the
  /// generator has real exercises and a real history to read.
  Future<AppStore> storeWithLibrary(WidgetTester tester) async {
    final clock = FakeClock();
    final backend = Backend.inMemory(clock: clock.now);
    addTearDown(backend.close);
    seedDemoData(backend, clock.now());
    await tester.runAsync(
      () => loadExerciseCatalogue(backend.db, backend.storage.exercises),
    );
    return AppStore(clock: clock.now, backend: backend, isOnboarded: true);
  }

  ProgramRequest request({int days = 4, Set<Equipment>? equipment}) =>
      ProgramRequest(
        goal: ProgramGoal.muscle,
        level: ProgramLevel.intermediate,
        days: days,
        minutes: 60,
        equipment: equipment ?? Equipment.values.toSet(),
      );

  testWidgets(
    'a program is kept as one 課表 per workout, named for what it trains',
    (tester) async {
      final store = await storeWithLibrary(tester);
      final before = store.routines.length;

      final saved = store.saveProgram(store.buildProgram(request()));

      expect(saved.map((routine) => routine.name), [
        '上肢 A',
        '下肢 A',
        '上肢 B',
        '下肢 B',
      ]);
      expect(store.routines.length, before + 4);
      for (final routine in saved) {
        expect(routine.exercises, isNotEmpty);
        expect(routine.programName, '生成的課表');
      }
      await disposeTree(tester);
    },
  );

  testWidgets('a workout that is the only one of its kind has no letter', (
    tester,
  ) async {
    final store = await storeWithLibrary(tester);

    final saved = store.saveProgram(store.buildProgram(request(days: 5)));

    expect(saved.map((routine) => routine.name), ['上肢', '下肢', '推', '拉', '腿']);
    await disposeTree(tester);
  });

  testWidgets(
    'an exercise already done carries a weight, one never done carries none',
    (tester) async {
      final store = await storeWithLibrary(tester);
      var weighted = 0;

      for (final workout in store.buildProgram(request()).workouts) {
        for (final planned in workout.exercises) {
          if (planned.exercise.recordCount == 0) {
            expect(planned.targetWeightKg, 0, reason: planned.exercise.id);
          } else if (planned.targetWeightKg > 0) {
            weighted++;
          }
        }
      }
      expect(weighted, greaterThan(0), reason: 'the demo has a history');
      await disposeTree(tester);
    },
  );

  testWidgets(
    'the training page offers it, and the answers change the result',
    (tester) async {
      final store = await storeWithLibrary(tester);
      await pumpScreen(
        tester,
        const TrainingScreen(),
        store: store,
        window: tallPhone,
      );

      await tester.scrollUntilVisible(
        find.text('生成課表'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('生成課表'));
      await tester.pumpAndSettle();

      // The demo lifts twice a week, so it starts as two full-body
      // workouts; a third day adds a third.
      expect(store.suggestedProgramRequest.days, 2);
      expect(find.textContaining('全身 B'), findsOneWidget);
      expect(find.textContaining('全身 C'), findsNothing);
      expect(find.textContaining('上肢'), findsNothing);

      await tester.tap(find.text('3 天'));
      await tester.pumpAndSettle();
      expect(find.textContaining('全身 C'), findsOneWidget);

      await tester.tap(find.text('4 天'));
      await tester.pumpAndSettle();
      expect(find.textContaining('上肢 A'), findsOneWidget);
      expect(find.textContaining('全身'), findsNothing);

      await tester.tap(find.text('徒手'));
      await tester.pumpAndSettle();
      expect(
        find.text('槓鈴臥推'),
        findsNothing,
        reason: 'no barbell with only the body to train with',
      );
      await disposeTree(tester);
    },
  );

  testWidgets('shuffling gives other exercises, and 儲存 keeps what is shown', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = await storeWithLibrary(tester);
    final before = store.routines.length;
    final days = store.suggestedProgramRequest.days;
    await pumpScreen(tester, const TrainingScreen(), store: store);
    await tester.scrollUntilVisible(
      find.text('生成課表'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('生成課表'));
    await tester.pumpAndSettle();

    final first = find.text('槓鈴深蹲');
    expect(first, findsOneWidget);
    await tester.tap(find.text('換一組'));
    await tester.pumpAndSettle();
    expect(find.text('槓鈴深蹲'), findsNothing);

    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();

    expect(store.routines.length, before + days);
    expect(find.text('已存成 $days 份課表'), findsOneWidget);
    await disposeTree(tester);
  });
}
