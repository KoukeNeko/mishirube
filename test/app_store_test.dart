import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/engines/set_schemes.dart';
import 'package:mishirube/backend/engines/training_metrics.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/seed/demo_content.dart';
import 'package:mishirube/features/nutrition/nutrition_view_model.dart';

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

    test('a set heavier than any before it counts as a personal record', () {
      store.startWorkout();
      final set = store.completeNextSet()!;

      final squat = store.activeWorkout!.exercises.first.exercise;
      expect(store.isPersonalRecord(squat, set), isTrue);
      expect(store.workoutReview(store.activeWorkout!).records, 1);
    });

    test('a workout is ready until it begins, and times from there', () {
      store.startWorkout();
      expect(store.activeWorkout!.isReady, isTrue);
      clock.advance(const Duration(minutes: 5));
      expect(store.activeWorkout!.elapsedAt(clock.now()), Duration.zero);

      store.beginWorkout();
      expect(store.activeWorkout!.isReady, isFalse);
      clock.advance(const Duration(minutes: 1));
      expect(
        store.activeWorkout!.elapsedAt(clock.now()),
        const Duration(minutes: 1),
        reason: 'the time looking it over is not training',
      );
    });

    test('the first set ticked begins a ready workout', () {
      store.startWorkout();
      clock.advance(const Duration(minutes: 3));
      store.completeNextSet();
      expect(store.activeWorkout!.isReady, isFalse);
      clock.advance(const Duration(minutes: 1));
      expect(
        store.activeWorkout!.elapsedAt(clock.now()),
        const Duration(minutes: 1),
      );
    });

    test('finishWorkout records duration and logs nothing else', () {
      store
        ..startWorkout()
        ..beginWorkout();
      clock.advance(const Duration(minutes: 58, seconds: 2));
      store.finishWorkout();

      final finished = store.lastFinishedWorkout!;
      final meals = store.todayMeals.length;
      expect(store.activeWorkout, isNull);
      expect(
        finished.elapsedAt(finished.finishedAt!),
        const Duration(minutes: 58, seconds: 2),
      );
      expect(store.todayMeals, hasLength(meals), reason: 'no sample lunch');
      expect(
        store.recentRoutineWorkouts.first.id,
        finished.id,
        reason: 'the template lists what was really done, newest first',
      );
    });

    test('a finished workout can be removed, and taken back', () {
      final before = store.lastFinishedWorkout;
      store
        ..startWorkout()
        ..completeNextSet()
        ..finishWorkout();
      final finished = store.lastFinishedWorkout!;

      store.deleteWorkout(finished.id);
      expect(store.lastFinishedWorkout?.id, before?.id);
      expect([
        for (final workout in store.recentWorkouts) workout.id,
      ], isNot(contains(finished.id)));

      store.restoreWorkout(finished.id);
      expect(store.lastFinishedWorkout!.id, finished.id);
    });

    test('a finished workout is corrected set by set', () {
      store
        ..startWorkout()
        ..addWarmups()
        ..completeNextSet()
        ..completeNextSet()
        ..completeNextSet()
        ..finishWorkout();
      final finished = store.lastFinishedWorkout!;
      final first = finished.exercises.first;
      final done = [
        for (final set in first.sets)
          if (set.isDone) set,
      ];
      final undone = first.sets.where((set) => !set.isDone).length;
      final added = store.exercises.firstWhere(
        (exercise) => finished.exercises.every(
          (session) => session.exercise.id != exercise.id,
        ),
      );

      store.correctWorkout(finished, [
        (
          exercise: first.exercise,
          was: first,
          loads: [
            for (final set in done)
              SetLoad(weightKg: set.weightKg + 5, reps: 3),
          ],
        ),
        (exercise: added, was: null, loads: [SetLoad(weightKg: 20, reps: 12)]),
      ]);

      final saved = store.workoutById(finished.id)!;
      final corrected = saved.exercises.first;
      expect(
        [
          for (final set in corrected.sets)
            if (set.isDone) (set.weightKg, set.reps, set.type),
        ],
        [for (final set in done) (set.weightKg + 5, 3, set.type)],
        reason: 'each set keeps its kind, a warm-up stays one',
      );
      expect(
        corrected.sets.where((set) => !set.isDone),
        hasLength(undone),
        reason: 'sets never done are left as they were',
      );
      expect(saved.exercises[1].exercise.id, added.id);
      expect(saved.exercises[1].sets.single.isDone, isTrue);
    });

    test('a finished workout can be moved and given a length', () {
      store
        ..startWorkout()
        ..completeNextSet()
        ..finishWorkout();
      final finished = store.lastFinishedWorkout!;
      final yesterday = finished.startedAt.subtract(const Duration(days: 1));

      store.correctWorkout(
        finished,
        [
          for (final session in finished.exercises)
            if (session.completedSets > 0)
              (
                exercise: session.exercise,
                was: session,
                loads: [
                  for (final set in session.sets)
                    if (set.isDone)
                      SetLoad(weightKg: set.weightKg, reps: set.reps),
                ],
              ),
        ],
        timing: (startedAt: yesterday, length: const Duration(minutes: 45)),
      );

      final saved = store.workoutById(finished.id)!;
      expect(saved.startedAt, yesterday);
      expect(saved.elapsedAt(saved.finishedAt!), const Duration(minutes: 45));
      expect(
        store.backend.timeline
            .month(DateTime(yesterday.year, yesterday.month))
            .days
            .any(
              (day) => day.entries.any(
                (entry) =>
                    entry.recordId == finished.id &&
                    entry.at.day == yesterday.day,
              ),
            ),
        isTrue,
        reason: 'it is listed on the day it was moved to',
      );
    });

    test('last night is the latest night, not a nap or an old one', () {
      final journal = store.backend.journal;
      journal.recordSleep(
        const Duration(hours: 1),
        at: clock.now(),
        kind: SleepKind.nap,
      );
      journal.recordSleep(
        const Duration(hours: 7),
        at: clock.now().subtract(const Duration(hours: 3)),
      );
      expect(store.lastNight?.entry.duration, const Duration(hours: 7));
    });

    test('a plan is timed by each exercise\'s rest and its planned times', () {
      final plank = store.exercises.firstWhere((e) => e.id == 'plank');
      final squat = store.exercises.firstWhere((e) => e.id == 'back-squat');
      PlannedExercise held(List<SetLoad> loads) =>
          PlannedExercise.ofLoads(store.backend.training.planFor(plank), loads);
      final plan = [
        held(const [SetLoad(seconds: 60), SetLoad(seconds: 30)]),
      ];

      expect(
        plannedDuration(plan),
        const Duration(seconds: 90) + restAfter(plank) * 2,
        reason: 'the time of each set, not a fixed 40 s',
      );
      store.setRestFor(plank, const Duration(seconds: 20));
      expect(
        plannedDuration(plan, restOf: store.restFor),
        const Duration(seconds: 130),
        reason: 'its own rest, 20 s',
      );

      final lifted = store.backend.training.planFor(squat).copyWith(sets: 2);
      expect(
        plannedDuration([lifted], restOf: store.restFor),
        (setWorkTime + store.restFor(squat)) * 2,
      );
      store.setRestFor(squat, Duration.zero);
      store.createRoutine('核心');
      store.addExercises([plank]);
      expect(
        store.backend.training.expectedLength(store.routine),
        plannedDuration(store.routine.exercises, restOf: store.restFor),
        reason: 'the estimate reads the stored rest',
      );
    });

    test('a template takes as long as its recent workouts did', () {
      store
        ..createRoutine('上肢')
        ..addExercises([DemoExercises.hipThrust]);
      final planned = plannedDuration(store.routine.exercises);
      expect(
        store.expectedMinutes(store.routine),
        (planned.inSeconds / 60).round(),
        reason: 'no workout yet, so the plan is the estimate',
      );

      store
        ..startWorkout()
        ..beginWorkout();
      clock.advance(const Duration(minutes: 40));
      store.finishWorkout();
      expect(store.expectedMinutes(store.routine), 40);
    });

    test('a sore muscle takes a set off its exercises today only', () {
      final first = store.routine.exercises.first;
      final muscle = first.exercise.primaryMuscles.first;
      store.startWorkout(sore: {muscle});

      expect(
        store.activeWorkout!.exercises.first.sets,
        hasLength(first.sets - 1),
      );
      expect(
        store.routine.exercises.first.sets,
        first.sets,
        reason: 'the template is left as it is',
      );
    });

    test('a superset takes a set of each before the rest', () {
      store.setJoinsNext(0, joins: true);
      store.startWorkout();
      final workout = store.activeWorkout!;
      expect(workout.supersetOf(0), [0, 1]);

      // Logged as from the workout page or the watch.
      expect(store.logNextSet()!.rests, isFalse);
      expect(workout.currentExerciseIndex, 1, reason: 'on to its partner');
      expect(store.restEndsAt, isNull);

      expect(store.logNextSet()!.rests, isTrue);
      expect(workout.currentExerciseIndex, 0, reason: 'round again');
      expect(store.restEndsAt, isNotNull);
      expect(
        store.backend.training.active()!.exercises.first.joinsNext,
        isTrue,
        reason: 'kept with the workout',
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

  group('sets from a scheme or an earlier session', () {
    List<WorkoutSet> working() => [
      for (final set in store.activeWorkout!.exercises.first.sets)
        if (set.type == SetType.working) set,
    ];

    test('a scheme replaces the sets still to do, and only those', () {
      store.startWorkout();
      store.addWarmups();
      // The warm-ups come first, then the first working set.
      while (!working().first.isDone) {
        store.completeNextSet();
      }
      final sets = store.activeWorkout!.exercises.first.sets;
      final warmups = sets.where((set) => set.type == SetType.warmup).toList();
      final done = sets.where((set) => set.isDone).toList();
      final firstWorking = working().first;
      expect(firstWorking.isDone, isTrue);

      store.applyScheme(
        0,
        schemeSets(SetScheme.fiveByFive, mainKg: 100, sets: 5, reps: 5),
      );

      final after = store.activeWorkout!.exercises.first.sets;
      expect(working(), hasLength(5), reason: '4 to do became 5 to make 5');
      expect(
        working().first,
        same(firstWorking),
        reason: 'done is not rewritten',
      );
      expect([
        for (final set in working().skip(1)) (set.weightKg, set.reps),
      ], everyElement((100.0, 5)));
      expect(
        after.where((set) => set.type == SetType.warmup),
        warmups,
        reason: 'warm-ups are left alone',
      );
      expect(after.where((set) => set.isDone), done);
      expect(
        store.backend.training.active()!.exercises.first.sets,
        hasLength(after.length),
        reason: 'written, not only held',
      );
      final actions = store.backend.db
          .select(
            'SELECT action FROM audit_events WHERE entity_id = ? ORDER BY id',
            [store.activeWorkout!.id],
          )
          .map((row) => row['action']);
      expect(actions.last, 'apply_scheme');
    });

    test('fewer loads than sets to do take the last ones off', () {
      store.startWorkout();
      store.applyScheme(0, [
        SetLoad(weightKg: 80.0, reps: 10),
        SetLoad(weightKg: 90.0, reps: 8),
      ]);

      expect(
        [for (final set in working()) (set.weightKg, set.reps)],
        [(80.0, 10), (90.0, 8)],
      );
    });

    test('done sets count toward the scheme: the rest take what follows', () {
      store.startWorkout();
      store.completeNextSet();
      store.applyScheme(0, [
        SetLoad(weightKg: 60.0, reps: 10),
        SetLoad(weightKg: 70.0, reps: 8),
        SetLoad(weightKg: 80.0, reps: 6),
      ]);

      expect(
        [for (final set in working()) (set.weightKg, set.reps)],
        [
          (working().first.weightKg, working().first.reps),
          (70.0, 8),
          (80.0, 6),
        ],
      );
      expect(working().first.isDone, isTrue);
      expect(working().first.weightKg, isNot(60), reason: 'left as it was');
    });

    test('an earlier session is read from what was done in it', () {
      store.startWorkout();
      final squat = store.activeWorkout!.exercises.first.exercise;
      final before = store.sessionsOf(squat);
      expect(before, isNotEmpty, reason: 'the demo has earlier squats');
      expect(
        before.map((session) => session.date),
        orderedEquals(
          [...before.map((s) => s.date)]..sort((a, b) => b.compareTo(a)),
        ),
        reason: 'newest first',
      );

      store.applyScheme(0, [SetLoad(weightKg: 102.5, reps: 3)]);
      store.completeNextSet();
      clock.advance(const Duration(hours: 1));
      store.finishWorkout();

      final after = store.sessionsOf(squat);
      expect(after, hasLength(before.length + 1));
      expect(
        [for (final set in after.first.sets) (set.weightKg, set.reps)],
        [(102.5, 3)],
        reason: 'only what was done',
      );
    });
  });

  group('a set being timed', () {
    WorkoutSet plankSet() => store.activeWorkout!.exercises.first.sets.first;

    setUp(() {
      final plank = store.exercises.firstWhere((e) => e.id == 'plank');
      store.startFreeWorkout([plank]);
    });

    test('starts the workout, counts, holds and stops with whole seconds', () {
      expect(store.activeWorkout!.isReady, isTrue);
      store.startSetTimer(plankSet());
      expect(store.activeWorkout!.isReady, isFalse, reason: 'timing begins it');

      clock.advance(const Duration(seconds: 20));
      store.toggleSetTimerPause();
      clock.advance(const Duration(minutes: 5));
      expect(
        store.setTimer!.elapsedAt(clock.now()),
        const Duration(seconds: 20),
      );
      store.toggleSetTimerPause();
      clock.advance(const Duration(seconds: 25));

      expect(store.stopSetTimer(), 45);
      expect(store.setTimer, isNull);
      expect(store.stopSetTimer(), isNull);
    });

    test('signals once at the planned time, and runs on', () {
      store.startSetTimer(plankSet());
      clock.advance(const Duration(seconds: 29));
      expect(store.settleSetTimer(), isFalse);
      clock.advance(const Duration(seconds: 1));
      expect(store.settleSetTimer(), isTrue, reason: '30 s planned');
      expect(store.settleSetTimer(), isFalse, reason: 'once');
      clock.advance(const Duration(seconds: 15));
      expect(store.setTimer!.elapsedAt(clock.now()).inSeconds, 45);
    });

    test('follows the set through an edit, and ends with it', () {
      store.startSetTimer(plankSet());
      store.editSet(0, weightKg: 0, reps: 0, rir: null, seconds: 40);
      expect(store.setTimer!.set, same(plankSet()));

      store.removeSet(0);
      expect(store.setTimer, isNull, reason: 'its set is gone');
    });
  });

  group('time and rest', () {
    test('adjusting the time counted moves the clock, and never below 0', () {
      store.startWorkout();
      store.adjustElapsed(const Duration(minutes: 5));
      expect(
        store.activeWorkout!.elapsedAt(clock.now()),
        Duration.zero,
        reason: 'nothing runs while it is only scheduled',
      );

      store.beginWorkout();
      clock.advance(const Duration(minutes: 30));
      store.adjustElapsed(const Duration(minutes: 5));
      expect(
        store.activeWorkout!.elapsedAt(clock.now()),
        const Duration(minutes: 35),
      );

      store.adjustElapsed(const Duration(minutes: -1));
      expect(
        store.activeWorkout!.elapsedAt(clock.now()),
        const Duration(minutes: 34),
      );

      store.adjustElapsed(const Duration(minutes: -60));
      expect(store.activeWorkout!.elapsedAt(clock.now()), Duration.zero);
      final actions = store.backend.db
          .select(
            'SELECT action FROM audit_events WHERE entity_id = ? ORDER BY id',
            [store.activeWorkout!.id],
          )
          .map((row) => row['action']);
      expect(actions, containsAll(['begin', 'adjust_time']));
    });

    test('shortening a rest to nothing ends it, never below', () {
      store.startWorkout();
      store.logNextSet();
      expect(store.restEndsAt, isNotNull);
      final length = store.restLength;

      store.extendRest(const Duration(seconds: -15));
      expect(store.restLength, length - const Duration(seconds: 15));
      expect(store.restEndsAt, isNotNull);

      clock.advance(length - const Duration(seconds: 20));
      store.extendRest(const Duration(seconds: -15));
      expect(store.restEndsAt, isNull, reason: 'to 0 is over');
      expect(store.restLength, greaterThanOrEqualTo(Duration.zero));
    });

    test('a rest set for an exercise is the one it starts with', () {
      store.startWorkout();
      final squat = store.activeWorkout!.exercises.first.exercise;
      expect(store.restFor(squat), restAfter(squat));

      store.setRestFor(squat, const Duration(seconds: 45));
      store.logNextSet();
      expect(store.restLength, const Duration(seconds: 45));
      expect(store.restFor(squat), const Duration(seconds: 45));

      store.setRestFor(squat, const Duration(hours: 1));
      expect(store.restFor(squat), maxRest, reason: 'within ten minutes');
    });

    test('with automatic rest off a set done starts no rest', () {
      store.startWorkout();
      expect(store.isAutoRest, isTrue);
      store.setAutoRest(false);

      expect(store.logNextSet()!.rests, isFalse);
      expect(store.restEndsAt, isNull);

      store.setAutoRest(true);
      store.logNextSet();
      expect(store.restEndsAt, isNotNull);
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
      final nutrition = NutritionViewModel(store.backend);
      addTearDown(nutrition.dispose);

      final snapshot = nutrition.splitDish(
        mealId: 'lunch',
        dishIndex: 0,
        day: store.now(),
      )!;
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

      nutrition.undoSplit(snapshot);
      // Read back from the database, so compared by what it holds.
      expect(
        [for (final dish in store.todayMeals.last.dishes) dish.name],
        [for (final dish in lunchBefore.dishes) dish.name],
      );
      expect(store.todayMeals.last.dishes.first.isComposite, isTrue);
    });

    test('splitDish ignores dishes without components', () {
      store.confirmLunch();
      final nutrition = NutritionViewModel(store.backend);
      addTearDown(nutrition.dispose);

      expect(
        nutrition.splitDish(mealId: 'lunch', dishIndex: 1, day: store.now()),
        isNull,
      );
    });
  });
}
