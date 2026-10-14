import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/exercise/exercise_picker_screen.dart';
import 'package:mishirube/features/training/edit_workout_screen.dart';

import '../../support/harness.dart';

/// Tall enough to build every exercise card at once.
const _tallPhone = WindowCase(
  'tall phone',
  Size(390, 3000),
  padding: FakeViewPadding(top: phoneTopInset, bottom: phoneBottomInset),
);

void main() {
  /// A store holding one finished workout of two exercises, each with a
  /// set done, and that workout.
  (AppStore, WorkoutSession) twoExercises() {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..startWorkout()
      ..completeNextSet()
      ..finishWorkout();
    final finished = store.lastFinishedWorkout!;
    final first = finished.exercises.first;
    final second = store.exercises.firstWhere(
      (exercise) =>
          exercise.trackingType == TrackingType.weightReps &&
          finished.exercises.every(
            (session) => session.exercise.id != exercise.id,
          ),
    );
    store.correctWorkout(finished, [
      (
        exercise: first.exercise,
        was: first,
        loads: [SetLoad(weightKg: 60, reps: 8)],
      ),
      (exercise: second, was: null, loads: [SetLoad(weightKg: 20, reps: 12)]),
    ]);
    return (store, store.workoutById(finished.id)!);
  }

  testWidgets('an exercise is swapped for another and keeps its sets', (
    tester,
  ) async {
    final (store, workout) = twoExercises();
    final was = workout.exercises.first.exercise;
    final replacement = store.exercises.firstWhere(
      (exercise) =>
          exercise.trackingType == was.trackingType &&
          workout.exercises.every(
            (session) => session.exercise.id != exercise.id,
          ),
    );
    await pumpScreen(tester, EditWorkoutScreen(workout: workout), store: store);

    await tester.tap(find.text('替換').first);
    await tester.pumpAndSettle();
    expect(find.byType(ExercisePickerScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), replacement.name);
    await tester.pumpAndSettle();
    // The search field holds the same words; the tile is the last.
    await tester.tap(find.text(replacement.name).last);
    await tester.pumpAndSettle();

    expect(find.byType(ExercisePickerScreen), findsNothing);
    expect(find.text(replacement.name), findsOneWidget);
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();

    final saved = store.workoutById(workout.id)!.exercises.first;
    expect(saved.exercise.id, replacement.id);
    expect(
      [
        for (final set in saved.sets.where((set) => set.isDone))
          (set.weightKg, set.reps),
      ],
      [(60.0, 8)],
      reason: 'what was done stays as it was',
    );
    await disposeTree(tester);
  });

  testWidgets('holding an exercise by its header puts it in another place', (
    tester,
  ) async {
    final (store, workout) = twoExercises();
    // The exercises with a set done are the ones the page shows.
    List<String> done(WorkoutSession session) => [
      for (final exercise in session.exercises)
        if (exercise.completedSets > 0) exercise.exercise.name,
    ];
    final names = done(workout);
    expect(names, hasLength(2));
    await pumpScreen(
      tester,
      EditWorkoutScreen(workout: workout),
      store: store,
      window: _tallPhone,
    );

    final header = tester.getCenter(find.text(names.first));
    final target =
        tester.getCenter(find.text(names.last)) + const Offset(0, 160);
    final gesture = await tester.startGesture(header);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    // In steps, as a finger moves, so the list sees it pass the next card.
    final steps = ((target.dy - header.dy) / 40).ceil();
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();

    expect(done(store.workoutById(workout.id)!), names.reversed.toList());
    await disposeTree(tester);
  });
}
