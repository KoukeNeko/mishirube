import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/seed/demo_content.dart';

import 'support/harness.dart';

void main() {
  late FakeClock clock;
  late AppStore store;

  setUp(() {
    clock = FakeClock();
    store = AppStore(clock: clock.now, isOnboarded: true);
  });

  group('workout', () {
    test('startWorkout builds one session per planned exercise', () {
      store.startWorkout();

      final workout = store.activeWorkout!;
      expect(workout.exercises, hasLength(store.routine.exercises.length));
      expect(workout.totalSets, store.routine.totalSets);
      expect(workout.completedSets, 0);
    });

    test('startWorkout twice keeps the running session', () {
      store.startWorkout();
      final first = store.activeWorkout;
      store.startWorkout();

      expect(store.activeWorkout, same(first));
    });

    test('completing every set of an exercise advances to the next one', () {
      store.startWorkout();
      final squatSets = store.activeWorkout!.currentExercise.sets.length;

      for (var i = 0; i < squatSets; i++) {
        store.completeNextSet();
      }

      expect(store.activeWorkout!.currentExerciseIndex, 1);
      expect(store.activeWorkout!.completedSets, squatSets);
    });

    test('a heavier target than last time counts as a personal record', () {
      store.startWorkout();
      store.completeNextSet();

      expect(store.activeWorkout!.personalRecords, 1);
    });

    test('finishWorkout records duration and moves Today to evening', () {
      store.startWorkout();
      clock.advance(const Duration(minutes: 58, seconds: 2));
      store.finishWorkout();

      final finished = store.lastFinishedWorkout!;
      expect(store.activeWorkout, isNull);
      expect(store.phase, DayPhase.evening);
      expect(
        finished.elapsedAt(finished.finishedAt!),
        const Duration(minutes: 58, seconds: 2),
      );
    });

    test('replaceCurrentExercise keeps the prescribed sets', () {
      store.startWorkout();
      store.replaceCurrentExercise(DemoExercises.gobletSquat);

      final current = store.activeWorkout!.currentExercise;
      expect(current.exercise, DemoExercises.gobletSquat);
      expect(current.sets, hasLength(4));
    });

    test('addExercises goes to the template when no workout runs', () {
      final before = store.routine.exercises.length;
      store.addExercises([DemoExercises.hipThrust]);

      expect(store.routine.exercises, hasLength(before + 1));
    });
  });

  group('plan changes', () {
    test('AI proposal changes the template, not finished workouts', () {
      store.startWorkout();
      store.completeNextSet();
      store.finishWorkout();
      final finishedSets =
          store.lastFinishedWorkout!.exercises.first.sets.length;

      store.applyAiProposal();

      final squat = store.routine.exercises.first;
      expect(squat.sets, 5);
      expect(
        store.lastFinishedWorkout!.exercises.first.sets,
        hasLength(finishedSets),
      );
    });
  });

  group('nutrition', () {
    test('confirmLunch adds lunch once', () {
      store.confirmLunch();
      store.confirmLunch();

      expect(
        store.todayMeals.where((meal) => meal.id == 'lunch'),
        hasLength(1),
      );
      expect(store.todayKcal, 560 + 620);
    });

    test('splitDish turns components into entries and can be undone', () {
      store.confirmLunch();
      final lunchBefore = store.todayMeals.last;

      final snapshot = store.splitDish(mealId: 'lunch', dishIndex: 0)!;
      final lunchAfter = store.todayMeals.last;
      expect(
        lunchAfter.dishes,
        hasLength(
          lunchBefore.dishes.length -
              1 +
              DemoNutrition.sandwich.components.length,
        ),
      );
      expect(lunchAfter.dishes.first.isComposite, isFalse);

      store.undoSplit(snapshot);
      expect(store.todayMeals.last, same(lunchBefore));
    });

    test('splitDish ignores dishes without components', () {
      store.confirmLunch();

      expect(store.splitDish(mealId: 'lunch', dishIndex: 1), isNull);
    });
  });

  test('cyclePhase walks morning → noon → evening → morning', () {
    final phases = [for (var i = 0; i < 3; i++) (store..cyclePhase()).phase];

    expect(phases, [DayPhase.noon, DayPhase.evening, DayPhase.morning]);
  });
}
