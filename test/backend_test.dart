import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/application/activity_service.dart';
import 'package:mishirube/backend/import_export/canonical_archive.dart';
import 'package:mishirube/backend/import_export/csv.dart';
import 'package:mishirube/backend/import_export/csv_view.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/backend/storage/schema.dart';
import 'package:mishirube/backend/engines/food_portion.dart';
import 'package:mishirube/backend/seed/catalogue.dart';
import 'package:mishirube/backend/storage/food_repository.dart';
import 'package:mishirube/backend/engines/nutrition_summary.dart';
import 'package:mishirube/backend/engines/training_metrics.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/nutrition/nutrition_view_model.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException, sqlite3;

import 'support/harness.dart';

void main() {
  late FakeClock clock;
  late Directory directory;

  setUp(() {
    clock = FakeClock();
    directory = Directory.systemTemp.createTempSync('mishirube_backend');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  Backend openFile() => Backend(
    AppDatabase.open('${directory.path}/store.sqlite3', clock: clock.now),
  );

  group('storage', () {
    test('a new database is migrated to the latest schema', () {
      final backend = Backend.inMemory(clock: clock.now);
      addTearDown(backend.close);

      expect(backend.db.schemaVersion, latestSchemaVersion);
    });

    test('data survives closing and reopening the file', () {
      final first = openFile();
      first.db.setSetting('probe', 'kept');
      first.close();

      final second = openFile();
      addTearDown(second.close);
      expect(second.db.setting('probe'), 'kept');
      expect(second.db.schemaVersion, latestSchemaVersion);
    });

    test('an unreadable file is set aside instead of taking the app down', () {
      final path = '${directory.path}/broken.sqlite3';
      File(path).writeAsStringSync('this is not a database');

      final db = AppDatabase.open(path, clock: clock.now);
      addTearDown(db.close);

      expect(db.schemaVersion, latestSchemaVersion, reason: 'a fresh start');
      expect(
        db.recoveredFrom,
        isNotNull,
        reason: 'the app can say where the old file went',
      );
      expect(File(db.recoveredFrom!).existsSync(), isTrue);
      expect(
        File(db.recoveredFrom!).readAsStringSync(),
        'this is not a database',
        reason: 'nothing is destroyed on the way',
      );
    });

    test('a database from a newer app is refused, not rewritten', () {
      final path = '${directory.path}/newer.sqlite3';
      sqlite3.open(path)
        ..userVersion = latestSchemaVersion + 1
        ..close();

      expect(() => AppDatabase.open(path), throwsStateError);
    });

    test('a failed transaction leaves neither the change nor its audit', () {
      final backend = Backend.inMemory(clock: clock.now);
      addTearDown(backend.close);
      int auditCount() =>
          backend.db.select('SELECT COUNT(*) AS n FROM audit_events').first['n']
              as int;
      final before = auditCount();

      expect(
        () => backend.db.transaction(() {
          backend.db.setSetting('half', 'written');
          throw StateError('crash between two writes');
        }),
        throwsStateError,
      );

      expect(backend.db.setting('half'), isNull);
      expect(auditCount(), before);
    });

    test('the store allows only one workout in progress', () {
      final store = AppStore(clock: clock.now, isOnboarded: true)
        ..startWorkout();
      addTearDown(store.dispose);
      final running = store.activeWorkout!;

      expect(
        () => store.backend.storage.workouts.save(
          WorkoutSession(
            id: 'second',
            routineName: running.routineName,
            startedAt: clock.now(),
            exercises: const [],
          ),
          action: 'start',
        ),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('workout persistence', () {
    test('a workout is restored as it was after the app is killed', () {
      final firstRun = openFile();
      AppStore(clock: clock.now, isOnboarded: true, backend: firstRun)
        ..startWorkout()
        ..completeNextSet()
        ..completeNextSet()
        ..togglePause();
      // No finish, no lifecycle callback: the process just dies.
      firstRun.close();

      final secondRun = openFile();
      addTearDown(secondRun.close);
      final store = AppStore(clock: clock.now, backend: secondRun);
      final workout = store.activeWorkout!;

      expect(store.isOnboarded, isTrue);
      expect(workout.completedSets, 2);
      expect(workout.isPaused, isTrue);
      expect(workout.currentExercise.exercise.id, 'back-squat');
      expect(workout.currentExercise.sets.first.previousWeightKg, 95);
    });

    test('every logged set is recorded in the audit trail', () {
      final store = AppStore(clock: clock.now, isOnboarded: true)
        ..startWorkout()
        ..completeNextSet();
      addTearDown(store.dispose);

      final actions = store.backend.db
          .select(
            'SELECT action FROM audit_events WHERE entity_id = ? ORDER BY id',
            [store.activeWorkout!.id],
          )
          .map((row) => row['action']);
      expect(actions, ['start', 'complete_set']);
    });

    test('changing the template never rewrites a finished workout', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(clock: clock.now, backend: backend)
        ..startWorkout()
        ..completeNextSet()
        ..finishWorkout();
      final finishedId = store.lastFinishedWorkout!.id;

      store.applyAiProposal();

      final reloaded = AppStore(clock: clock.now, backend: backend);
      expect(reloaded.routine.exercises.first.sets, 5);
      final finished = backend.storage.workouts.byId(
        finishedId,
        (id) => backend.storage.exercises.byId(id)!,
      )!;
      expect(finished.exercises.first.sets, hasLength(4));
      final aiChange = backend.db.select(
        "SELECT source FROM audit_events WHERE action = 'accept_ai_proposal'",
      );
      expect(aiChange.single['source'], ChangeSource.aiDraft.name);
    });

    test('editing a plan never touches a finished workout', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(clock: clock.now, backend: backend)
        ..startWorkout()
        ..completeNextSet()
        ..finishWorkout();
      final finishedId = store.lastFinishedWorkout!.id;
      final planned = [
        for (final exercise in store.routine.exercises) exercise.exercise.id,
      ];

      store
        ..moveRoutineExercise(0, 2)
        ..removeRoutineExercise(0)
        ..renameRoutine('下肢 B');

      final reloaded = AppStore(clock: clock.now, backend: backend);
      expect(reloaded.routine.name, '下肢 B');
      expect(
        [for (final e in reloaded.routine.exercises) e.exercise.id],
        [planned[2], planned[0], planned[3], planned[4]],
      );
      final finished = backend.storage.workouts.byId(
        finishedId,
        (id) => backend.catalog.byId(id)!,
      )!;
      expect(
        [for (final e in finished.exercises) e.exercise.id],
        planned,
        reason: 'the workout keeps the exercises it was done with',
      );
    });

    test('a finished workout can be opened again by its id', () {
      final store = AppStore(clock: clock.now, isOnboarded: true);
      addTearDown(store.dispose);
      final september = store.backend.timeline.month(DateTime(2026, 9));
      final training = september.days
          .expand((day) => day.entries)
          .firstWhere((entry) => entry.category == RecordCategory.training);

      final workout = store.workoutById(training.recordId!)!;

      expect(workout.routineName, training.title);
      expect(workout.finishedAt, isNotNull);
      expect(store.workoutById('no-such-workout'), isNull);
    });

    test('a note written during a workout is kept with the record', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store =
          AppStore(clock: clock.now, isOnboarded: true, backend: backend)
            ..startWorkout()
            ..setWorkoutNotes('睡不好，握力先到極限');

      expect(
        AppStore(clock: clock.now, backend: backend).activeWorkout!.notes,
        '睡不好，握力先到極限',
      );

      store
        ..completeNextSet()
        ..finishWorkout();
      expect(store.lastFinishedWorkout!.notes, '睡不好，握力先到極限');
    });

    test('a finished workout becomes the next "last time"', () {
      final store = AppStore(clock: clock.now, isOnboarded: true)
        ..startWorkout();
      addTearDown(store.dispose);
      for (var i = 0; i < 4; i++) {
        store.completeNextSet();
      }
      store.finishWorkout();

      final squat = store.exercises.firstWhere((e) => e.id == 'back-squat');
      expect(squat.lastPerformance, '上次 100 kg × 5');
      expect(squat.lastUsedDaysAgo, 0);
      store.startWorkout();
      expect(
        store.activeWorkout!.exercises.first.sets.first.previousWeightKg,
        100,
      );
    });
  });

  group('routine persistence', () {
    test('a new template is trained from next, across a restart', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      final before = store.routines.length;

      final created = store.createRoutine('上肢 B');
      expect(store.routines, hasLength(before + 1));
      expect(store.routine.id, created.id);
      expect(created.exercises, isEmpty);

      final reopened = AppStore(clock: clock.now, backend: backend);
      expect(
        reopened.routine.id,
        created.id,
        reason: 'the choice of what to train is not lost on restart',
      );
    });

    test('deleting a template keeps the workouts done from it', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      final deleted = store.routine;
      final workouts = store.backend.timeline
          .month(DateTime(2026, 9))
          .days
          .expand((day) => day.entries)
          .where((entry) => entry.category == RecordCategory.training)
          .length;

      expect(store.deleteRoutine(deleted), isTrue);
      expect(store.routines.map((r) => r.id), isNot(contains(deleted.id)));
      expect(
        store.routine.id,
        isNot(deleted.id),
        reason: 'moved on to another',
      );
      expect(
        store.backend.timeline
            .month(DateTime(2026, 9))
            .days
            .expand((day) => day.entries)
            .where((entry) => entry.category == RecordCategory.training)
            .length,
        workouts,
        reason: 'the plan is gone, the history is not',
      );

      store.undeleteRoutine(deleted.id);
      expect(store.routines.map((r) => r.id), contains(deleted.id));
      expect(store.routine.id, deleted.id);
    });

    test('the last template is kept, so there is always one to train', () {
      final store = AppStore(clock: clock.now, isOnboarded: true);
      addTearDown(store.dispose);

      for (final routine in [...store.routines.skip(1)]) {
        expect(store.deleteRoutine(routine), isTrue);
      }
      expect(store.routines, hasLength(1));
      expect(store.deleteRoutine(store.routine), isFalse);
      expect(store.routines, hasLength(1));
    });
  });

  group('replacing an exercise', () {
    test('only today leaves the template alone', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      )..startWorkout();
      final planned = store.routine.exercises.first.exercise;
      final replacement = store.exercises.firstWhere(
        (exercise) => exercise.id != planned.id,
      );

      store.replaceCurrentExercise(replacement);

      expect(store.activeWorkout!.currentExercise.exercise.id, replacement.id);
      expect(
        store.routine.exercises.first.exercise.id,
        planned.id,
        reason: 'the plan is unchanged unless the user says so',
      );
    });

    test('updating the template keeps what was planned for the slot', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      )..startWorkout();
      final slot = store.routine.exercises.first;
      final replacement = store.exercises.firstWhere(
        (exercise) => exercise.id != slot.exercise.id,
      );

      store.replaceCurrentExercise(replacement, updateTemplate: true);

      final reopened = AppStore(clock: clock.now, backend: backend);
      final updated = reopened.routine.exercises.first;
      expect(updated.exercise.id, replacement.id);
      expect(updated.sets, slot.sets);
      expect(updated.reps, slot.reps);
      expect(updated.targetWeightKg, slot.targetWeightKg);
      expect(
        reopened.routine.exercises,
        hasLength(store.routine.exercises.length),
        reason: 'a swap, not an addition',
      );
    });
  });

  group('weekly goal persistence', () {
    test('the goal and its pause survive a restart', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      expect(
        store.backend.goal.isEnabled,
        isFalse,
        reason: 'nothing set by default',
      );
      expect(store.backend.goal.overview().hasGoal, isFalse);

      store.backend.goal.setGoal(4, applyThisWeek: true);
      store.backend.goal.pause();

      final reopened = AppStore(clock: clock.now, backend: backend);
      expect(reopened.backend.goal.isEnabled, isTrue);
      expect(reopened.backend.goal.overview().thisWeek.targetDays, 4);
      expect(reopened.backend.goal.overview().isPaused, isTrue);

      reopened.backend.goal.resume();
      expect(
        AppStore(
          clock: clock.now,
          backend: backend,
        ).backend.goal.overview().isPaused,
        isFalse,
      );
    });

    test('a day with a workout and a run counts once', () {
      final store = AppStore(clock: clock.now, isOnboarded: true)
        ..backend.goal.setGoal(5, applyThisWeek: true);
      addTearDown(store.dispose);
      final before = store.backend.goal.overview().thisWeek.activeDays;

      store.backend.activity
        ..log(
          type: ActivityTypes.running,
          startedAt: clock.now(),
          duration: const Duration(minutes: 30),
        )
        ..log(
          type: ActivityTypes.cycling,
          startedAt: clock.now().subtract(const Duration(hours: 3)),
          duration: const Duration(minutes: 40),
        );

      expect(
        store.backend.goal.overview().thisWeek.activeDays,
        before + 1,
        reason: 'two records on one day are still one active day',
      );
    });

    test('a late record brings the week, and the run, back', () {
      final store = AppStore(clock: clock.now, isOnboarded: true)
        ..backend.goal.setGoal(3, applyThisWeek: true);
      addTearDown(store.dispose);
      final short = store.backend.goal.overview().weeks.lastWhere(
        (week) => !week.isCurrent && !week.isMet && !week.isPaused,
      );
      final before = store.backend.goal.overview().streak;

      // Fill that week in, as if catching up on records.
      for (var i = 0; i < short.targetDays - short.activeDays; i++) {
        store.backend.activity.log(
          type: ActivityTypes.walking,
          startedAt: short.start.add(Duration(days: i, hours: 9)),
          duration: const Duration(minutes: 30),
        );
      }

      final after = store.backend.goal.overview();
      final filled = after.weeks.firstWhere(
        (week) => week.start == short.start,
      );
      expect(filled.isMet, isTrue);
      expect(
        after.streak.current,
        greaterThan(before.current),
        reason: 'filling the week in counts it; no repair needed',
      );
    });
  });

  group('nutrition persistence', () {
    test('a saved food survives a restart and can be logged', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      final food = FoodItem(
        id: store.backend.nutrition.newFoodId(),
        name: '雞胸肉',
        brand: '大成',
        servingLabel: '一片',
        servingAmount: 100,
        servingUnit: ServingUnit.gram,
        kcal: 165,
        proteinGrams: 31,
        carbGrams: 0,
        fatGrams: 4,
      );
      store.backend.nutrition.saveFood(food);

      final reopened = AppStore(clock: clock.now, backend: backend);
      final stored = reopened.backend.nutrition.searchFoods('雞胸').single;
      expect(stored.displayName, '大成 雞胸肉');
      expect(stored.kcal, 165);

      final before = reopened.todayKcal;
      final logged = reopened.backend.nutrition.logPortion(
        FoodPortion(stored, 2),
      );
      expect(logged.kcal, 330);
      expect(logged.proteinGrams, 62);
      expect(reopened.todayKcal, before + 330);
      expect(
        AppStore(clock: clock.now, backend: backend).todayMeals.last.kcal,
        330,
      );
    });

    test("a label's decimals are kept, and a meal rounds once", () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      store.backend.nutrition.saveFood(
        FoodItem(
          id: store.backend.nutrition.newFoodId(),
          name: '吐司',
          servingAmount: 100,
          servingUnit: ServingUnit.gram,
          kcal: 274.4,
          proteinGrams: 6.7,
          carbGrams: 48.4,
          fatGrams: 6.0,
        ),
      );

      final reopened = AppStore(clock: clock.now, backend: backend);
      final stored = reopened.backend.nutrition.searchFoods('吐司').single;
      expect(stored.kcal, 274.4);
      expect(stored.proteinGrams, 6.7);
      expect(stored.carbGrams, 48.4);

      // 6.7 × 1.5 is 10.05: rounded from the exact figure, not from 7.
      final logged = reopened.backend.nutrition.logPortion(
        FoodPortion(stored, 1.5),
      );
      expect(logged.proteinGrams, 10);
      expect(logged.kcal, 412, reason: '274.4 × 1.5 = 411.6');
    });

    test('a quick record is logged like a food but keeps none', () {
      final store = AppStore(clock: clock.now, isOnboarded: true);
      addTearDown(store.dispose);
      final saved = store.backend.nutrition.searchFoods('').length;

      final logged = store.backend.nutrition.logOnce(
        FoodPortion(
          const FoodItem(id: 'cake', name: '同事帶的蛋糕', kcal: 320.5),
          1,
        ),
        mealType: MealType.snack,
      );

      expect(logged.kcal, 321);
      expect(logged.mealType, MealType.snack);
      expect(logged.foodId, isNull, reason: 'nothing to offer again');
      expect(store.backend.nutrition.searchFoods(''), hasLength(saved));
      expect(
        store.backend.nutrition.recentFoods().map((r) => r.food.name),
        isNot(contains('同事帶的蛋糕')),
      );
    });

    test('a different portion is worked out, not retyped', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      final rice = FoodItem(
        id: store.backend.nutrition.newFoodId(),
        name: '白飯',
        servingAmount: 100,
        servingUnit: ServingUnit.gram,
        kcal: 130,
        proteinGrams: 3,
        carbGrams: 28,
        fatGrams: 0,
      );
      store.backend.nutrition.saveFood(rice);

      final byAmount = FoodPortion.ofAmount(rice, 150);
      expect(byAmount.servings, 1.5);
      expect(byAmount.kcal, 195);
      expect(byAmount.label, '150 g');

      final byServings = FoodPortion(rice, 1.5);
      expect(byServings.amount, 150);
      expect(byServings.kcal, byAmount.kcal);

      final logged = store.backend.nutrition.logPortion(byAmount);
      expect(logged.kcal, 195);
      expect(logged.dishes.single.quantityLabel, '150 g');
    });

    test('an unmeasured serving stays in servings', () {
      final store = AppStore(clock: clock.now, isOnboarded: true);
      addTearDown(store.dispose);
      const bento = FoodItem(
        id: 'bento',
        name: '排骨便當',
        servingLabel: '一個',
        kcal: 800,
        proteinGrams: 30,
        carbGrams: 100,
        fatGrams: 28,
      );

      expect(bento.servingUnit, ServingUnit.serving);
      expect(bento.servingDescription, '一個');
      final half = FoodPortion(bento, 0.5);
      expect(half.kcal, 400);
      expect(half.label, '0.5 份');
      expect(
        FoodPortion.ofAmount(bento, 2).servings,
        2,
        reason: 'there is nothing to convert from, so the number is servings',
      );
    });

    test('a nutrient nobody wrote down never becomes zero', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      final milk = FoodItem(
        id: store.backend.nutrition.newFoodId(),
        name: '鮮奶',
        kind: ConsumptionKind.beverage,
        servingAmount: 250,
        servingUnit: ServingUnit.millilitre,
        kcal: 160,
        proteinGrams: 8,
        carbGrams: 12,
        fatGrams: 8,
        nutrients: const {Nutrient.calcium: 250, Nutrient.sodium: 100},
      );
      store
        ..backend.nutrition.saveFood(milk)
        ..backend.nutrition.logPortion(FoodPortion(milk, 2));

      final stored = AppStore(
        clock: clock.now,
        backend: backend,
      ).backend.nutrition.searchFoods('鮮奶').single;
      expect(stored.nutrients[Nutrient.calcium], 250);
      expect(
        stored.nutrients.containsKey(Nutrient.iron),
        isFalse,
        reason: 'the label said nothing about iron, so neither do we',
      );

      final meal = store.todayMeals.last;
      expect(meal.nutrients[Nutrient.calcium], 500, reason: 'two servings');
      expect(meal.nutrients.containsKey(Nutrient.iron), isFalse);
    });

    test('a day total says how much of the day it could not see', () {
      final store = AppStore(clock: clock.now, isOnboarded: true);
      addTearDown(store.dispose);
      const milk = FoodItem(
        id: 'milk',
        name: '鮮奶',
        kind: ConsumptionKind.beverage,
        servingAmount: 250,
        servingUnit: ServingUnit.millilitre,
        kcal: 160,
        proteinGrams: 8,
        carbGrams: 12,
        fatGrams: 8,
        nutrients: {Nutrient.calcium: 250},
      );
      const rice = FoodItem(
        id: 'rice',
        name: '白飯',
        servingAmount: 100,
        servingUnit: ServingUnit.gram,
        kcal: 130,
        proteinGrams: 3,
        carbGrams: 28,
        fatGrams: 0,
      );
      store
        ..backend.nutrition.logPortion(const FoodPortion(milk, 1))
        ..backend.nutrition.logPortion(const FoodPortion(rice, 1));

      final calcium = summariseNutrients(
        store.todayMeals,
      ).singleWhere((total) => total.nutrient == Nutrient.calcium);

      expect(calcium.amount, 250);
      expect(calcium.isComplete, isFalse, reason: 'the rice said nothing');
      expect(calcium.label, '至少 250 mg');
      expect(
        summariseNutrients(
          store.todayMeals,
        ).any((total) => total.nutrient == Nutrient.iron),
        isFalse,
        reason: 'a nutrient nobody recorded is left out, not listed as 0',
      );
    });

    test('a food logged without figures never reads as no calories', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      final unknown = FoodItem(
        id: store.backend.nutrition.newFoodId(),
        name: '路邊攤炒麵',
        servingAmount: 1,
        servingUnit: ServingUnit.serving,
      );
      const known = FoodItem(
        id: 'rice',
        name: '白飯',
        servingAmount: 100,
        servingUnit: ServingUnit.gram,
        kcal: 130,
        proteinGrams: 3,
        carbGrams: 28,
        fatGrams: 0,
      );
      final before = summariseDay(store.todayMeals, isOver: false);
      store
        ..backend.nutrition.saveFood(unknown)
        ..backend.nutrition.logPortion(FoodPortion(unknown, 1))
        ..backend.nutrition.logPortion(const FoodPortion(known, 1));

      final reopened = AppStore(clock: clock.now, backend: backend);
      expect(reopened.backend.nutrition.searchFoods('炒麵').single.kcal, isNull);
      expect(
        reopened.todayMeals.map((meal) => meal.kcal),
        contains(isNull),
        reason: 'the meal has no figure either, rather than a made-up zero',
      );

      final summary = summariseDay(reopened.todayMeals, isOver: false);
      expect(
        summary.kcal,
        before.kcal + 130,
        reason: 'the meal with no figure adds nothing, not a zero',
      );
      expect(summary.mealsWithoutFigures, 1);
      expect(summary.countsEveryMeal, isFalse);
    });

    test('fluid is what was logged by volume, with no hydration factor', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      const water = FoodItem(
        id: 'water',
        name: '水',
        kind: ConsumptionKind.beverage,
        servingAmount: 500,
        servingUnit: ServingUnit.millilitre,
        kcal: 0,
      );
      const coffee = FoodItem(
        id: 'coffee',
        name: '黑咖啡',
        kind: ConsumptionKind.beverage,
        servingAmount: 240,
        servingUnit: ServingUnit.millilitre,
        kcal: 5,
        nutrients: {Nutrient.caffeine: 95},
      );
      const rice = FoodItem(
        id: 'rice',
        name: '白飯',
        servingAmount: 100,
        servingUnit: ServingUnit.gram,
        kcal: 130,
      );
      final before = summariseFluid(store.todayMeals);
      store
        ..backend.nutrition.logPortion(const FoodPortion(water, 1))
        ..backend.nutrition.logPortion(const FoodPortion(coffee, 1))
        ..backend.nutrition.logPortion(const FoodPortion(rice, 1));

      final fluid = summariseFluid(
        AppStore(clock: clock.now, backend: backend).todayMeals,
      );
      expect(
        fluid.millilitres,
        before.millilitres + 740,
        reason: '500 + 240; the coffee counts in full and the rice not at all',
      );
      expect(fluid.drinkCount, before.drinkCount + 2);
      expect(
        store.todayMeals.last.millilitres,
        isNull,
        reason: 'food measured in grams has no volume, and no guess is made',
      );
    });

    test('a portion can be written in any unit of the same kind', () {
      const chicken = FoodItem(
        id: 'chicken',
        name: '雞胸肉',
        servingAmount: 100,
        servingUnit: ServingUnit.gram,
        kcal: 165,
        proteinGrams: 31,
      );

      // Half a pound of something sold by the 100 g.
      final byPound = FoodPortion.ofAmount(
        chicken,
        0.5,
        unit: ServingUnit.pound,
      );
      expect(byPound.servings, closeTo(2.268, 0.001));
      expect(byPound.kcal, 374);

      // A Taiwanese catty is 600 g, so six servings exactly.
      final byCatty = FoodPortion.ofAmount(chicken, 1, unit: ServingUnit.catty);
      expect(byCatty.servings, 6);
      expect(byCatty.kcal, 165 * 6);

      const milk = FoodItem(
        id: 'milk',
        name: '鮮奶',
        kind: ConsumptionKind.beverage,
        servingAmount: 250,
        servingUnit: ServingUnit.millilitre,
        kcal: 160,
      );
      final byLitre = FoodPortion.ofAmount(milk, 1, unit: ServingUnit.litre);
      expect(byLitre.servings, 4);
      expect(
        byLitre.millilitres,
        1000,
        reason: 'a litre of milk is a litre of drink',
      );
    });

    test('a cup size carries its own figures, not the small one scaled', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      final americano = FoodItem(
        id: store.backend.nutrition.newFoodId(),
        name: '美式咖啡',
        brand: '星巴克',
        kind: ConsumptionKind.beverage,
        servingAmount: 240,
        servingUnit: ServingUnit.millilitre,
        kcal: 5,
      );
      store.backend.nutrition.saveFood(americano);
      // Short 240 ml / 98 mg, Tall 350 ml / 195 mg: the cup is 1.5 times
      // bigger and the caffeine is double, because the shots differ.
      for (final (name, ml, caffeine) in [
        ('Short', 240.0, 98.0),
        ('Tall', 350.0, 195.0),
      ]) {
        store.backend.nutrition.saveFood(
          FoodItem(
            id: store.backend.nutrition.newFoodId(),
            name: '美式咖啡',
            brand: '星巴克',
            kind: ConsumptionKind.beverage,
            parentId: americano.id,
            sizeName: name,
            servingAmount: ml,
            servingUnit: ServingUnit.millilitre,
            kcal: 5,
            nutrients: {Nutrient.caffeine: caffeine},
          ),
        );
      }

      final reopened = AppStore(clock: clock.now, backend: backend);
      expect(
        reopened.backend.nutrition.searchFoods(''),
        hasLength(1),
        reason: 'sizes belong to the drink, they are not loose in the list',
      );

      final sizes = reopened.backend.nutrition.sizesOf(americano.id);
      expect(sizes.map((size) => size.sizeName), ['Short', 'Tall']);
      expect(sizes.last.displayName, '星巴克 美式咖啡 Tall');
      expect(sizes.last.nutrients[Nutrient.caffeine], 195);
      expect(reopened.backend.nutrition.sizeNamesFor('星巴克'), [
        'Short',
        'Tall',
      ], reason: 'the next drink from the same shop offers the same cups');

      final tall = reopened.backend.nutrition.logPortion(
        FoodPortion(sizes.last, 1),
      );
      expect(tall.nutrients[Nutrient.caffeine], 195);
      expect(tall.millilitres, 350);
    });

    test('soup is poured but is not a drink', () {
      final store = AppStore(clock: clock.now, isOnboarded: true);
      addTearDown(store.dispose);
      // Both are measured in millilitres; only one of them is drunk.
      const soup = FoodItem(
        id: 'soup',
        name: '玉米濃湯',
        kind: ConsumptionKind.food,
        servingAmount: 350,
        servingUnit: ServingUnit.millilitre,
        kcal: 180,
      );
      const tea = FoodItem(
        id: 'tea',
        name: '無糖綠茶',
        kind: ConsumptionKind.beverage,
        servingAmount: 500,
        servingUnit: ServingUnit.millilitre,
        kcal: 0,
      );
      final before = summariseFluid(store.todayMeals);
      store
        ..backend.nutrition.logPortion(const FoodPortion(soup, 1))
        ..backend.nutrition.logPortion(const FoodPortion(tea, 1));

      final fluid = summariseFluid(store.todayMeals);
      expect(
        fluid.millilitres,
        before.millilitres + 500,
        reason: 'the tea counts and the soup does not',
      );
      expect(store.todayMeals[store.todayMeals.length - 2].millilitres, isNull);
    });

    test('drinks do not make a day of meals look complete', () {
      final store = AppStore(clock: clock.now, isOnboarded: true);
      addTearDown(store.dispose);
      const water = FoodItem(
        id: 'water',
        name: '水',
        kind: ConsumptionKind.beverage,
        servingAmount: 500,
        servingUnit: ServingUnit.millilitre,
        kcal: 0,
      );
      final before = summariseDay(store.todayMeals).mealCount;
      for (var i = 0; i < 3; i++) {
        store.backend.nutrition.logPortion(const FoodPortion(water, 1));
      }

      expect(
        summariseDay(store.todayMeals).mealCount,
        before,
        reason: 'three glasses of water is not three meals',
      );
    });

    test('which sitting it was is recorded only when the user says', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      const toast = FoodItem(
        id: 'toast',
        name: '吐司',
        kind: ConsumptionKind.food,
        servingAmount: 1,
        kcal: 150,
      );
      store
        ..backend.nutrition.logPortion(
          const FoodPortion(toast, 1),
          mealType: MealType.breakfast,
        )
        ..backend.nutrition.logPortion(const FoodPortion(toast, 1));

      final reopened = AppStore(clock: clock.now, backend: backend).todayMeals;
      expect(reopened[reopened.length - 2].mealType, MealType.breakfast);
      expect(
        reopened.last.mealType,
        isNull,
        reason: 'the clock is not asked to guess which meal it was',
      );
    });

    test('a ceiling stays a ceiling, and says so', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      // What a Taiwanese chain has to publish is a maximum per cup, not
      // the amount in the cup.
      final latte = FoodItem(
        id: store.backend.nutrition.newFoodId(),
        name: '拿鐵',
        brand: 'CITY CAFE',
        kind: ConsumptionKind.beverage,
        valueType: NutrientValueType.max,
        sourceUrl: 'https://example.invalid/citycafe.pdf',
        checkedAt: clock.now(),
        servingAmount: 360,
        servingUnit: ServingUnit.millilitre,
        kcal: 180,
        nutrients: const {Nutrient.caffeine: 180},
      );
      store.backend.nutrition.saveFood(latte);

      final stored = AppStore(
        clock: clock.now,
        backend: backend,
      ).backend.nutrition.searchFoods('拿鐵').single;
      expect(stored.valueType, NutrientValueType.max);
      expect(stored.sourceUrl, 'https://example.invalid/citycafe.pdf');
      expect(stored.checkedAt, isNotNull);

      final logged = store.backend.nutrition.logPortion(FoodPortion(stored, 1));
      expect(
        logged.valueType,
        NutrientValueType.max,
        reason: 'the record remembers what kind of number it copied',
      );
      expect(
        AppStore(clock: clock.now, backend: backend).todayMeals.last.valueType,
        NutrientValueType.max,
      );
    });

    test('a catalogue drink is read-only and keeps its sizes apart', () {
      final backend = openFile();
      addTearDown(backend.close);
      final foods = backend.storage.foods;
      // The shape a bundled file describes: a drink and its cups, each
      // cup carrying its own figures.
      final parsed = parseCatalogue({
        'brand': '星巴克',
        'sourceUrl': 'https://example.invalid/tw/menu',
        'checkedAt': '2026-09-21',
        'valueType': 'declared',
        'drinks': [
          {
            'id': 'sbux-tw-americano',
            'name': '美式咖啡',
            'sizes': [
              {'name': 'Short', 'millilitres': 240, 'caffeineMg': 98},
              {'name': 'Tall', 'millilitres': 350, 'caffeineMg': 195},
            ],
          },
        ],
      });
      for (final food in parsed) {
        foods.save(food, source: ChangeSource.catalogue);
      }

      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      final drink = store.backend.nutrition.searchFoods('美式').single;
      expect(drink.isBuiltIn, isTrue);
      expect(drink.sourceUrl, 'https://example.invalid/tw/menu');

      final sizes = store.backend.nutrition.sizesOf(drink.id);
      expect(sizes.map((size) => size.sizeName), ['Short', 'Tall']);
      expect(sizes.last.nutrients[Nutrient.caffeine], 195);
      expect(
        sizes.last.servingAmount,
        350,
        reason: 'the cup is the serving, so the volume scales with it',
      );

      // Editing or deleting it is refused where it matters, not only in
      // the screens.
      expect(
        () => foods.save(drink.copyWith(name: '改過的')),
        throwsA(isA<BuiltInFoodRefused>()),
      );
      expect(() => foods.delete(drink.id), throwsA(isA<BuiltInFoodRefused>()));

      // The catalogue itself may replace it, which is how an update works.
      foods.save(
        drink.copyWith(name: '美式咖啡（新配方）'),
        source: ChangeSource.catalogue,
      );
      expect(
        AppStore(
          clock: clock.now,
          backend: backend,
        ).backend.nutrition.searchFoods('美式').single.name,
        '美式咖啡（新配方）',
      );
    });

    test('the bundled catalogue files parse into drinks and cups', () {
      Map<String, dynamic> read(String path) =>
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      for (final path in catalogueFiles) {
        final parsed = parseCatalogue(read(path));
        expect(parsed, isNotEmpty, reason: path);
        expect(
          parsed.map((food) => food.id).toSet(),
          hasLength(parsed.length),
          reason: 'two cups sharing an id would overwrite each other',
        );
        for (final food in parsed) {
          expect(food.brand, isNotEmpty);
          expect(food.sourceUrl, startsWith('https://'));
          expect(
            food.isCupCapacity,
            food.servingUnit == ServingUnit.millilitre,
            reason: 'the chains publish cup sizes, not what is drunk',
          );
        }
      }

      final parsed = parseCatalogue(read('assets/catalogue/starbucks-tw.json'));
      for (final food in parsed) {
        expect(food.brand, '星巴克');
        expect(food.kind, ConsumptionKind.beverage);
        expect(food.servingUnit, ServingUnit.millilitre);
        expect(
          food.servingAmount,
          greaterThan(0),
          reason: 'a cup with no volume cannot be logged',
        );
        expect(
          food.sourceUrl,
          isNotEmpty,
          reason: 'a figure nobody can check should not ship',
        );
        expect(food.checkedAt, isNotNull);
      }

      // The americano is the one with a published figure for every cup.
      final americano = parsed.where(
        (food) => food.name == '美式咖啡' && food.sizeName.isNotEmpty,
      );
      expect(americano.map((size) => size.sizeName), ['小杯', '中杯', '大杯', '特大杯']);
      expect(
        americano.map((size) => size.nutrients[Nutrient.caffeine]),
        [98, 195, 293, 390],
        reason: 'the cups are not proportional, so each carries its own',
      );
    });

    test('a cup size is named, never counted as fluid drunk', () {
      final backend = openFile();
      addTearDown(backend.close);
      final parsed = parseCatalogue({
        'brand': '7-ELEVEN',
        'sourceUrl': 'https://example.invalid/ingredient.pdf',
        'checkedAt': '2026-09-21',
        'valueType': 'max',
        'volumeIs': 'cup',
        'drinks': [
          {
            'id': '7eleven-americano',
            'name': '美式咖啡',
            'sizes': [
              {
                'name': '大杯・冰',
                'millilitres': 480,
                'kcal': 21.6,
                'sugarG': 0.0,
                'caffeineMg': 302.0,
              },
            ],
          },
        ],
      });
      for (final food in parsed) {
        backend.storage.foods.save(food, source: ChangeSource.catalogue);
      }

      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      final cup = store.backend.nutrition.sizesOf('7eleven-americano').single;
      expect(cup.isCupCapacity, isTrue, reason: 'it survives the database');
      expect(cup.servingDescription, '杯容量 480 ml');
      expect(
        cup.kcal,
        22,
        reason: 'a ceiling of 21.6 rounds up, so "at most" stays true',
      );
      expect(cup.nutrients[Nutrient.sugar], 0);
      expect(cup.nutrients[Nutrient.caffeine], 302);

      final nutrition = NutritionViewModel(store.backend);
      addTearDown(nutrition.dispose);
      final fluidBefore = nutrition.todayFluid.millilitres;
      final logged = store.backend.nutrition.logPortion(FoodPortion(cup, 1));
      expect(
        logged.millilitres,
        isNull,
        reason: 'an iced 480 ml cup is partly ice',
      );
      expect(nutrition.todayFluid.millilitres, fluidBefore);
    });

    test('a chain lists its lines apart and drops what it stopped selling', () {
      final backend = openFile();
      addTearDown(backend.close);
      final foods = backend.storage.foods;
      List<FoodItem> line(String series, List<Map<String, dynamic>> drinks) =>
          parseCatalogue({
            'brand': '7-ELEVEN',
            'series': series,
            'sourceUrl': 'https://example.invalid/ingredient.pdf',
            'checkedAt': '2026-09-21',
            'valueType': 'max',
            'volumeIs': 'cup',
            'drinks': drinks,
          });
      final shipped = [
        ...line('CITY CAFE', [
          {
            'id': 'cafe-latte',
            'name': '燕麥拿鐵',
            'sizes': [
              {'name': '中杯・冰', 'millilitres': 360, 'kcal': 174.6},
            ],
          },
        ]),
        ...line('不可思議咖啡', [
          {
            'id': 'reserve-latte',
            'name': '燕麥拿鐵',
            'sizes': [
              {'name': '專用杯・熱', 'kcal': 166.4, 'caffeineMg': 162.7},
            ],
          },
          {
            'id': 'reserve-pearls',
            'name': '原味黑珠',
            'kind': 'food',
            'kcal': 285.6,
            'sugarG': 30.0,
          },
        ]),
      ];
      for (final food in shipped) {
        foods.save(food, source: ChangeSource.catalogue);
      }

      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      expect(
        store.backend.nutrition
            .menuOf('7-ELEVEN')
            .map((food) => food.displayName),
        [
          '7-ELEVEN CITY CAFE 燕麥拿鐵',
          '7-ELEVEN 不可思議咖啡 原味黑珠',
          '7-ELEVEN 不可思議咖啡 燕麥拿鐵',
        ],
        reason: 'the same name in two lines is two drinks',
      );
      expect(store.backend.nutrition.searchFoods('city cafe'), isNotEmpty);

      final mug = store.backend.nutrition.sizesOf('reserve-latte').single;
      expect(
        mug.servingUnit,
        ServingUnit.serving,
        reason: 'a cup whose capacity was not published has no volume',
      );
      expect(mug.isCupCapacity, isFalse);
      expect(mug.servingDescription, '一杯');
      final pearls = store.backend.nutrition.menuOf('7-ELEVEN')[1];
      expect(pearls.kind, ConsumptionKind.food);
      expect(store.backend.nutrition.sizesOf(pearls.id), isEmpty);
      expect(pearls.kcal, 286);

      // The next release no longer ships the pearls.
      foods.retireCatalogue({
        for (final food in shipped)
          if (food.id != 'reserve-pearls') food.id,
      });
      expect(
        store.backend.nutrition.menuOf('7-ELEVEN').map((food) => food.name),
        ['燕麥拿鐵', '燕麥拿鐵'],
      );
    });

    test('correcting a food does not rewrite the meals logged from it', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      final food = FoodItem(
        id: store.backend.nutrition.newFoodId(),
        name: '豆漿',
        kind: ConsumptionKind.beverage,
        servingAmount: 250,
        servingUnit: ServingUnit.millilitre,
        kcal: 130,
        proteinGrams: 10,
        carbGrams: 12,
        fatGrams: 5,
      );
      store
        ..backend.nutrition.saveFood(food)
        ..backend.nutrition.logPortion(FoodPortion(food, 1));

      store.backend.nutrition.saveFood(food.copyWith(kcal: 90));

      expect(store.backend.nutrition.searchFoods('豆漿').single.kcal, 90);
      expect(
        AppStore(clock: clock.now, backend: backend).todayMeals.last.kcal,
        130,
        reason:
            'the meal copied the numbers; the correction is not a claim '
            'about what was drunk',
      );
    });

    test('deleting a food hides it and can be undone', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      final food = FoodItem(
        id: store.backend.nutrition.newFoodId(),
        name: '地瓜',
        servingLabel: '一條',
        kcal: 130,
        proteinGrams: 2,
        carbGrams: 30,
        fatGrams: 0,
      );
      store
        ..backend.nutrition.saveFood(food)
        ..backend.nutrition.logPortion(FoodPortion(food, 1))
        ..backend.nutrition.deleteFood(food.id);

      expect(store.backend.nutrition.searchFoods(''), isEmpty);
      expect(
        AppStore(clock: clock.now, backend: backend).todayMeals.last.kcal,
        130,
        reason: 'removing a food is not a change to what was eaten',
      );

      store.backend.nutrition.undeleteFood(food.id);
      expect(store.backend.nutrition.searchFoods('').single.name, '地瓜');
    });

    test('an exploded dish and its undo are both stored', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      )..confirmLunch();
      final lunchDishes = store.todayMeals.last.dishes.length;
      final nutrition = NutritionViewModel(store.backend);
      addTearDown(nutrition.dispose);

      final snapshot = nutrition.splitDish(
        mealId: 'lunch',
        dishIndex: 0,
        day: clock.now(),
      )!;
      final exploded = AppStore(clock: clock.now, backend: backend);
      expect(exploded.todayMeals.last.dishes, hasLength(lunchDishes + 4));

      nutrition.undoSplit(snapshot);
      final restored = AppStore(clock: clock.now, backend: backend);
      expect(restored.todayMeals.last.dishes, hasLength(lunchDishes));
      expect(restored.todayMeals.last.dishes.first.components, hasLength(5));
    });

    test('recent meals come from the records and can be logged again', () {
      final store = AppStore(clock: clock.now, isOnboarded: true);
      addTearDown(store.dispose);
      final nutrition = NutritionViewModel(store.backend);
      addTearDown(nutrition.dispose);

      final recent = nutrition.recentMeals;
      expect(recent, hasLength(3));
      expect(recent.first.eatenAt.isAfter(recent.last.eatenAt), isTrue);
      expect(
        recent.map((meal) => meal.label).toSet(),
        hasLength(3),
        reason: 'the same dish is offered once, not once per day',
      );

      final before = store.todayKcal;
      final again = nutrition.copyMeal(recent.first.meal);

      expect(store.todayMeals.last.id, again.id);
      expect(store.todayKcal, before + recent.first.meal.kcal!);
      expect(
        again.id,
        isNot(recent.first.meal.id),
        reason: 'a copy, not a link back to the meal eaten before',
      );
    });

    test('a past day can be read and its dish exploded', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      final yesterday = clock.now().subtract(const Duration(days: 1));
      final meals = store.backend.nutrition.mealsOn(yesterday);
      final summary = store.backend.nutrition.summaryOf(yesterday);

      expect(meals, hasLength(1));
      expect(summary.mealCount, 1);
      expect(summary.isComplete, isFalse, reason: 'only one meal that day');

      final nutrition = NutritionViewModel(backend);
      addTearDown(nutrition.dispose);
      final snapshot = nutrition.splitDish(
        mealId: meals.single.id,
        dishIndex: 0,
        day: yesterday,
      )!;
      expect(
        AppStore(
          clock: clock.now,
          backend: backend,
        ).backend.nutrition.mealsOn(yesterday).single.dishes,
        hasLength(5),
      );
      expect(store.todayMeals, hasLength(1), reason: 'today is untouched');

      nutrition.undoSplit(snapshot);
      expect(
        store.backend.nutrition.mealsOn(yesterday).single.dishes,
        hasLength(1),
      );
    });

    test('a lunch on a later day gets its own id', () {
      final backend = openFile();
      addTearDown(backend.close);
      AppStore(clock: clock.now, backend: backend).confirmLunch();
      clock.advance(const Duration(days: 1));

      final nextDay = AppStore(clock: clock.now, backend: backend);
      expect(nextDay.isLunchLogged, isFalse);
      nextDay.confirmLunch();
      expect(nextDay.todayMeals.single.id, isNot('lunch'));
    });
  });

  group('activity persistence', () {
    test('a logged session survives a restart and lands on the log', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      final startedAt = clock.now().subtract(const Duration(minutes: 40));
      store.backend.activity.log(
        type: ActivityTypes.running,
        startedAt: startedAt,
        duration: const Duration(minutes: 40),
        distanceMeters: 6400,
        effort: 6,
        note: '河濱',
      );

      final reopened = AppStore(clock: clock.now, backend: backend);
      final today = reopened.activitiesOn(clock.now());
      expect(today.map((session) => session.type), [ActivityTypes.running]);
      expect(today.single.distanceMeters, 6400);
      expect(today.single.effort, 6);
      expect(today.single.pace, const Duration(minutes: 6, seconds: 15));

      final entries = reopened.backend.timeline
          .month(DateTime(2026, 9))
          .days
          .first
          .entries;
      expect(
        entries.where((entry) => entry.category == RecordCategory.activity),
        hasLength(1),
      );
    });

    test('a correction keeps the record, and a removal can be undone', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      final logged = store.backend.activity.log(
        type: ActivityTypes.running,
        startedAt: clock.now().subtract(const Duration(minutes: 30)),
        duration: const Duration(minutes: 30),
        distanceMeters: 5000,
      );

      store.backend.activity.edit(
        ActivitySession(
          id: logged.id,
          type: ActivityTypes.cycling,
          startedAt: logged.startedAt,
          duration: const Duration(minutes: 55),
          distanceMeters: 21000,
        ),
      );
      final corrected = AppStore(
        clock: clock.now,
        backend: backend,
      ).backend.activity.byId(logged.id)!;
      expect(corrected.type, ActivityTypes.cycling);
      expect(corrected.duration, const Duration(minutes: 55));

      store.backend.activity.delete(logged.id);
      expect(store.backend.activity.byId(logged.id), isNull);
      expect(
        store.activitiesOn(clock.now()).map((session) => session.id),
        isNot(contains(logged.id)),
      );

      store.backend.activity.restore(logged.id);
      expect(store.backend.activity.byId(logged.id), isNotNull);
      expect(
        AppStore(
          clock: clock.now,
          backend: backend,
        ).backend.activity.byId(logged.id),
        isNotNull,
        reason: 'the undo is written through, not only held in memory',
      );
    });

    test('a timed session survives a restart and stops into a record', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      expect(store.startActivity(ActivityTypes.running), isTrue);
      clock.advance(const Duration(minutes: 10));

      final reopened = AppStore(clock: clock.now, backend: backend);
      expect(reopened.activeSession, isA<ActiveActivity>());
      expect(reopened.activeActivity!.type, ActivityTypes.running);
      expect(
        reopened.activeActivity!.elapsedAt(clock.now()),
        const Duration(minutes: 10),
        reason: 'the clock runs from the start that was stored',
      );

      reopened.togglePause();
      clock.advance(const Duration(minutes: 5));
      reopened.togglePause();
      clock.advance(const Duration(minutes: 2));
      final finished = reopened.finishActivity()!;

      expect(finished.duration, const Duration(minutes: 12));
      expect(reopened.activeSession, isNull);
      expect(
        AppStore(
          clock: clock.now,
          backend: backend,
        ).backend.activity.byId(finished.id)?.duration,
        const Duration(minutes: 12),
        reason: 'the paused five minutes are not exercise',
      );
    });

    test('a discarded session leaves no record behind', () {
      final store = AppStore(clock: clock.now, isOnboarded: true);
      addTearDown(store.dispose);
      final before = store.backend.activity.summary().sessions;

      store.startActivity(ActivityTypes.swimming);
      clock.advance(const Duration(minutes: 20));
      store.discardActivity();

      expect(store.activeSession, isNull);
      expect(store.backend.activity.summary().sessions, before);
      expect(store.startActivity(ActivityTypes.swimming), isTrue);
    });

    test('one session at a time, and neither ends the other', () {
      final store = AppStore(clock: clock.now, isOnboarded: true);
      addTearDown(store.dispose);

      store.startActivity(ActivityTypes.running);
      expect(store.startWorkout(), isFalse);
      expect(
        store.activeSession,
        isA<ActiveActivity>(),
        reason: 'the refused start left the run alone',
      );
      expect(store.activeWorkout, isNull);

      store.finishActivity();
      expect(store.startWorkout(), isTrue);
      expect(store.startActivity(ActivityTypes.cycling), isFalse);
      expect(store.activeSession, isA<ActiveWorkout>());
    });

    test('exercise is counted apart from training', () {
      final store = AppStore(clock: clock.now, isOnboarded: true);
      addTearDown(store.dispose);

      final summary = store.backend.activity.summary();
      expect(summary.hasRecords, isTrue);
      expect(summary.thisWeek, 2, reason: 'the two sessions since Monday');
      expect(summary.weekly, hasLength(4));
      expect(summary.minutesThisWeek, 82, reason: 'the ride and the run');
      expect(
        summary.typicalWeeklyMinutes,
        isNotNull,
        reason: 'three finished weeks are enough for a normal week',
      );
      final workouts = store.backend.insights.trends().workoutsThisWeek;
      store.backend.activity.log(
        type: ActivityTypes.swimming,
        startedAt: clock.now().subtract(const Duration(minutes: 45)),
        duration: const Duration(minutes: 45),
      );
      expect(store.backend.activity.summary().thisWeek, summary.thisWeek + 1);
      expect(
        store.backend.insights.trends().workoutsThisWeek,
        workouts,
        reason: 'a swim is not a workout',
      );
    });

    test('the form starts from what was done last', () {
      final store = AppStore(clock: clock.now, isOnboarded: true);
      addTearDown(store.dispose);

      expect(store.backend.activity.recentTypes().first, ActivityTypes.cycling);
      expect(
        store.backend.activity.startingDuration(ActivityTypes.running),
        const Duration(minutes: 32),
      );
      expect(
        store.backend.activity.startingDuration(ActivityTypes.badminton),
        defaultActivityDuration,
        reason: 'nothing logged before, so a round half hour',
      );
    });
  });

  group('derived history', () {
    test('Epley estimates and ignores sets it cannot estimate', () {
      expect(estimateOneRepMax(100, 1), 100);
      expect(estimateOneRepMax(90, 5), closeTo(105, 0.001));
      expect(estimateOneRepMax(60, maxRepsForEstimate + 1), isNull);
      expect(estimateOneRepMax(0, 5), isNull);
    });

    test('warm-ups count neither for volume nor for the heaviest set', () {
      final sets = [
        WorkoutSet(
          weightKg: 120,
          reps: 1,
          previousWeightKg: 0,
          previousReps: 0,
          type: SetType.warmup,
          isDone: true,
        ),
        WorkoutSet(
          weightKg: 100,
          reps: 5,
          previousWeightKg: 0,
          previousReps: 0,
          isDone: true,
        ),
        WorkoutSet(
          weightKg: 110,
          reps: 5,
          previousWeightKg: 0,
          previousReps: 0,
        ),
      ];

      expect(volumeKg(sets), 500);
      expect(heaviestSet(sets)!.weightKg, 100);
    });

    test('exercise history comes from finished workouts', () {
      final store = AppStore(clock: clock.now, isOnboarded: true);
      addTearDown(store.dispose);
      final squat = store.exercises.firstWhere((e) => e.id == 'back-squat');
      final history = store.exerciseHistory(squat);

      expect(squat.recordCount, history.sessionCount);
      expect(history.last!.weightKg, 95);
      expect(history.last!.date, DateTime(2026, 9, 16, 18, 30));
      expect(history.estimatedOneRepMaxKg, closeTo(95 * (1 + 5 / 30), 0.001));
      expect(squat.lastUsedDaysAgo, 3);
    });

    test('the timeline merges domains and flags incomplete food days', () {
      final store = AppStore(clock: clock.now, isOnboarded: true);
      addTearDown(store.dispose);
      final september = store.backend.timeline.month(DateTime(2026, 9));

      final today = september.days.first;
      expect(today.label, '今天 · 9 月 19 日（週六）');
      expect(today.warning, isNull, reason: 'today is not over yet');
      expect(today.entries.map((e) => e.title), ['早餐', '體重 72.4 kg']);

      final yesterday = september.days[1];
      expect(yesterday.warning, '有未記錄的餐');
      expect(yesterday.entries.first.title, '精力 3 / 5');

      expect(september.dots[16], [
        RecordCategory.training,
        RecordCategory.nutrition,
      ]);
      expect(september.dots.containsKey(7), isFalse);
    });

    test('a finished workout shows up on the timeline with its record', () {
      final store = AppStore(clock: clock.now, isOnboarded: true)
        ..startWorkout();
      addTearDown(store.dispose);
      for (var i = 0; i < 4; i++) {
        store.completeNextSet();
      }
      clock.advance(const Duration(minutes: 58));
      store.finishWorkout();

      final entry = store.backend.timeline
          .month(DateTime(2026, 9))
          .days
          .first
          .entries
          .first;
      expect(entry.category, RecordCategory.training);
      expect(entry.detail, '4 組 · 58 分 · 槓鈴深蹲 100 kg × 5 為個人紀錄');
    });
  });

  group('merging a duplicate exercise', () {
    test('the history moves across and the duplicate stops being offered', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      final canonical = store.exercises.firstWhere((e) => e.id == 'back-squat');
      final duplicate = ExerciseDefinition(
        id: 'custom-squat',
        name: '深蹲（自己建的）',
        equipment: canonical.equipment,
        primaryMuscles: canonical.primaryMuscles,
        pattern: canonical.pattern,
        trackingType: canonical.trackingType,
        source: ExerciseSource.custom,
      );
      store.createExercise(duplicate);

      // Do a workout of the duplicate, so it has a history to move.
      store
        ..addExercises([duplicate])
        ..startWorkout();
      final index = store.activeWorkout!.exercises.indexWhere(
        (session) => session.exercise.id == duplicate.id,
      );
      store.selectExercise(index);
      store.completeNextSet();
      clock.advance(const Duration(minutes: 30));
      store.finishWorkout();

      final before = store.exerciseHistory(canonical).sessionCount;
      expect(store.exerciseHistory(duplicate).sessionCount, 1);

      store.mergeExercise(duplicate: duplicate, canonical: canonical);

      final reopened = AppStore(clock: clock.now, backend: backend);
      final merged = reopened.exercises.firstWhere((e) => e.id == 'back-squat');
      expect(
        reopened.exerciseHistory(merged).sessionCount,
        before + 1,
        reason: 'the session moved, it was not lost',
      );
      expect(
        reopened.exercises.map((e) => e.id),
        isNot(contains(duplicate.id)),
        reason: 'the duplicate is no longer offered',
      );
      expect(
        reopened.backend.timeline.month(DateTime(2026, 9)).days.first.entries,
        isNotEmpty,
        reason: 'the workout itself is untouched',
      );
    });
  });

  group('body measurements', () {
    test('only what was measured is recorded, and it reaches the log', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );

      store
        ..backend.journal.recordMeasurement(MeasurementSite.waist, 81.5)
        ..backend.journal.recordMeasurement(MeasurementSite.arm, 34);

      final reopened = AppStore(clock: clock.now, backend: backend);
      final latest = reopened.backend.journal.latestMeasurements();
      expect(latest.keys, {MeasurementSite.waist, MeasurementSite.arm});
      expect(latest[MeasurementSite.waist]!.centimetres, 81.5);
      expect(
        latest.containsKey(MeasurementSite.hips),
        isFalse,
        reason: 'a site that was not measured has no figure, not a zero',
      );

      final today = reopened.backend.timeline
          .month(DateTime(2026, 9))
          .days
          .first;
      expect(
        today.entries.where((e) => e.title.startsWith('腰圍')),
        hasLength(1),
      );
      expect(
        today.entries.where((e) => e.category == RecordCategory.body),
        hasLength(3),
        reason: 'the weight and both measurements',
      );
    });

    test('a later measurement replaces the one shown as last', () {
      final store = AppStore(clock: clock.now, isOnboarded: true);
      addTearDown(store.dispose);

      store.backend.journal.recordMeasurement(MeasurementSite.waist, 82);
      clock.advance(const Duration(days: 7));
      store.backend.journal.recordMeasurement(MeasurementSite.waist, 80.5);

      expect(
        store.backend.journal
            .latestMeasurements()[MeasurementSite.waist]!
            .centimetres,
        80.5,
      );
    });
  });

  group('favourite meals', () {
    test('a starred meal is offered again and survives a restart', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      );
      final nutrition = NutritionViewModel(store.backend);
      addTearDown(nutrition.dispose);
      expect(nutrition.favoriteMeals, isEmpty);
      final meal = nutrition.recentMeals.first;

      nutrition.setMealFavorite(meal.meal, isFavorite: true);

      final reopened = AppStore(clock: clock.now, backend: backend);
      expect(reopened.backend.nutrition.favorites().map((m) => m.label), [
        meal.label,
      ]);

      // Logging it again keeps the star on the one that was starred.
      final copy = reopened.backend.nutrition.copy(meal.meal);
      expect(copy.isFavorite, isFalse);
      expect(
        AppStore(
          clock: clock.now,
          backend: backend,
        ).backend.nutrition.favorites(),
        hasLength(1),
      );

      reopened.backend.nutrition.setFavorite(meal.meal, isFavorite: false);
      expect(
        AppStore(
          clock: clock.now,
          backend: backend,
        ).backend.nutrition.favorites(),
        isEmpty,
      );
    });
  });

  group('muscle load from records', () {
    test('the demo history is led by what the routine trains', () {
      final store = AppStore(clock: clock.now, isOnboarded: true);
      addTearDown(store.dispose);

      final load = store.backend.insights.muscleLoad();
      expect(load, isNotEmpty);
      expect(
        load.first.$1,
        isIn([MuscleGroup.quads, MuscleGroup.glutes, MuscleGroup.hamstrings]),
        reason: 'the demo trains lower body most',
      );
      expect(
        load.every((entry) => entry.$2 > 0),
        isTrue,
        reason: 'a muscle with nothing to show is left out, not shown as 0',
      );
    });

    test('finishing a workout shows up in the counts', () {
      final store = AppStore(clock: clock.now, isOnboarded: true)
        ..startWorkout();
      addTearDown(store.dispose);
      final before = {
        for (final (muscle, sets) in store.backend.insights.muscleLoad())
          muscle: sets,
      };

      for (var i = 0; i < 6; i++) {
        store.completeNextSet();
      }
      clock.advance(const Duration(minutes: 40));
      store.finishWorkout();

      final after = {
        for (final (muscle, sets) in store.backend.insights.muscleLoad())
          muscle: sets,
      };
      expect(
        after[MuscleGroup.quads],
        greaterThanOrEqualTo(before[MuscleGroup.quads]!),
      );
      expect(after.keys, containsAll(before.keys));
    });
  });

  group('meal type', () {
    test('can be changed or cleared after the fact, and is audited', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      final meal = store.backend.nutrition.logPortion(
        FoodPortion(FoodItem(id: 'latte', name: '拿鐵', kcal: 190), 1),
      );
      expect(meal.mealType, isNull);

      NutritionViewModel(store.backend)
        ..updateMeal(meal, meal.copyWith(mealType: MealType.breakfast))
        ..dispose();
      final reopened = store.backend.nutrition
          .mealsOn(store.now())
          .firstWhere((m) => m.id == meal.id);
      expect(reopened.mealType, MealType.breakfast, reason: 'it was saved');

      final audit = store.backend.db.select(
        "SELECT payload FROM audit_events WHERE entity_id = ? "
        "AND action = 'edit'",
        [meal.id],
      );
      expect(audit, hasLength(1));
    });

    test('the suggestion comes from the user, not the clock', () {
      final clock = FakeClock()..current = DateTime(2026, 9, 1, 15);
      final store = AppStore(clock: clock.now, isOnboarded: true);
      final nutrition = NutritionViewModel(store.backend);
      addTearDown(nutrition.dispose);
      expect(nutrition.suggestedMealType(), isNull);

      for (var day = 0; day < 2; day++) {
        store.backend.nutrition.logPortion(
          FoodPortion(FoodItem(id: 'rice$day', name: '便當', kcal: 700), 1),
          mealType: MealType.lunch,
        );
        clock.advance(const Duration(days: 1));
      }

      expect(
        nutrition.suggestedMealType(),
        MealType.lunch,
        reason: 'two lunches at three o\'clock make three o\'clock lunch',
      );
    });
  });

  group('logging several foods at once', () {
    FoodItem food(String id, String name, {double kcal = 100}) => FoodItem(
      id: id,
      name: name,
      kcal: kcal,
      servingUnit: ServingUnit.gram,
      servingAmount: 100,
    );

    test('recent lists each food once, at the portion it was last eaten', () {
      final clock = FakeClock();
      final backend = Backend.inMemory(clock: clock.now);
      addTearDown(backend.close);
      final chicken = backend.nutrition.saveFood(food('chicken', '雞胸肉'));
      backend.nutrition.logPortion(FoodPortion(chicken, 1.5));
      clock.advance(const Duration(days: 1));
      backend.nutrition.logPortion(
        FoodPortion(chicken, 2),
        mealType: MealType.dinner,
      );

      final recent = backend.nutrition.recentFoods();
      expect(
        recent.where((r) => r.food.id == 'chicken'),
        hasLength(1),
        reason: 'two portions of one food are one row, not two',
      );
      expect(recent.first.servings, 2, reason: 'the last one wins');
      expect(recent.first.mealType, MealType.dinner);
      expect(recent.first.portion.amount, 200);
    });

    test('a deleted food is no longer offered', () {
      final backend = Backend.inMemory(clock: FakeClock().now);
      addTearDown(backend.close);
      final egg = backend.nutrition.saveFood(food('egg', '蛋', kcal: 70));
      backend.nutrition.logPortion(FoodPortion(egg, 1));

      backend.nutrition.deleteFood('egg');
      expect(backend.nutrition.recentFoods(), isEmpty);
      expect(
        backend.nutrition.mealsOn(FakeClock().now()).single.kcal,
        70,
        reason: 'what was eaten stays: its numbers were copied',
      );
    });

    test('a plate is logged, and undone, as one', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      final before = store.todayMeals.length;
      final plate = store.backend.nutrition.logPortions([
        FoodPortion(food('rice', '白飯', kcal: 130), 1.5),
        FoodPortion(food('egg', '蛋', kcal: 70), 2),
      ], mealType: MealType.lunch);

      expect(store.todayMeals, hasLength(before + 2));
      expect(plate.map((m) => m.mealType).toSet(), {MealType.lunch});

      final nutrition = NutritionViewModel(store.backend);
      addTearDown(nutrition.dispose);
      nutrition.deleteMeals(plate);
      expect(store.todayMeals, hasLength(before));
      nutrition.restoreMeals(plate);
      expect(store.todayMeals, hasLength(before + 2));
    });

    test('the source food survives a backup', () {
      final backend = Backend.inMemory(clock: FakeClock().now);
      addTearDown(backend.close);
      final rice = backend.nutrition.saveFood(food('rice', '白飯'));
      backend.nutrition.logPortion(FoodPortion(rice, 1.5));

      final restored = Backend.inMemory(clock: FakeClock().now);
      addTearDown(restored.close);
      restoreArchive(
        restored.db,
        jsonDecode(encodeArchive(exportArchive(backend.db))),
      );
      expect(restored.nutrition.recentFoods().single.servings, 1.5);
    });
  });

  group('finding a chain\'s drinks', () {
    /// A small shipped menu, loaded the way the app loads the real one.
    Backend withMenu() {
      final backend = Backend.inMemory(clock: FakeClock().now);
      final parsed = parseCatalogue({
        'brand': '星巴克',
        'brandAliases': ['Starbucks'],
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
                {'name': 'Grande', 'millilitres': 470, 'caffeineMg': 225},
              ],
            },
        ],
      });
      for (final food in parsed) {
        backend.storage.foods.save(food, source: ChangeSource.catalogue);
      }
      backend.nutrition.saveFood(
        const FoodItem(id: 'own', name: '自己泡的那堤', kcal: 120),
      );
      return backend;
    }

    test('the brand and its other spelling find the same drink', () {
      final backend = withMenu();
      addTearDown(backend.close);
      List<String> ids(String query) => [
        for (final food in backend.nutrition.searchFoods(query)) food.id,
      ];

      expect(ids('星巴克 那堤'), ['latte']);
      expect(ids('starbucks 那堤'), ['latte']);
      expect(ids('STARBUCKS'), containsAll(['latte', 'mocha']));
    });

    test('a name that starts with the words beats one that contains them', () {
      final backend = withMenu();
      addTearDown(backend.close);

      expect(backend.nutrition.searchFoods('那堤').map((f) => f.id).toList(), [
        'latte',
        'own',
      ], reason: '那堤 starts one name and is only inside the other');
    });

    test('naming a chain on its own offers its menu', () {
      final backend = withMenu();
      addTearDown(backend.close);

      expect(backend.nutrition.brandsNamedBy('星巴克'), ['星巴克']);
      expect(backend.nutrition.brandsNamedBy('star'), ['星巴克']);
      expect(backend.nutrition.brandsNamedBy('那堤'), isEmpty);
      expect(backend.nutrition.menuOf('星巴克').map((f) => f.id).toList(), [
        'mocha',
        'latte',
      ], reason: 'the drinks, not their cup sizes');
    });

    test('a starred cup survives the menu being shipped again', () {
      final backend = withMenu();
      addTearDown(backend.close);
      backend.nutrition.setFoodFavorite('latte-Grande', isFavorite: true);

      // An app update writes the whole catalogue over again.
      for (final food in backend.storage.foods.all()) {
        if (food.isBuiltIn) {
          backend.storage.foods.save(food, source: ChangeSource.catalogue);
        }
      }
      expect(backend.nutrition.favoriteFoods().map((f) => f.displayName), [
        '星巴克 那堤 Grande',
      ]);

      backend.nutrition.setFoodFavorite('latte-Grande', isFavorite: false);
      expect(backend.nutrition.favoriteFoods(), isEmpty);
    });
  });

  group('notes', () {
    test('a day note sits in the log on its day and round-trips', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      store.backend.journal.recordNote('晚上聚餐，吃得比平常多');

      final today = store.backend.timeline.month(store.now()).days.first;
      final row = today.entries.firstWhere((entry) => entry.title == '筆記');
      expect(row.detail, '晚上聚餐，吃得比平常多');
      expect(row.category, RecordCategory.wellness);

      final archive = jsonDecode(
        encodeArchive(exportArchive(store.backend.db)),
      );
      final restored = Backend.inMemory(clock: FakeClock().now);
      addTearDown(restored.close);
      restoreArchive(restored.db, archive);
      expect(
        restored.journal.entry(row.recordId!),
        isA<Note>().having((note) => note.text, 'text', '晚上聚餐，吃得比平常多'),
      );
    });

    test('a note is not a summary of the day', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      store.backend.journal.recordNote('頭痛');
      final summaries =
          store.backend.timeline.month(store.now()).summaries[store
              .now()
              .day] ??
          {};
      expect(
        summaries[RecordCategory.wellness] ?? '',
        isNot(contains('頭痛')),
        reason: 'the calendar line stays about sleep and check-ins',
      );
    });
  });

  group('data sources', () {
    test('tell demo records, typed records and the catalogue apart', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      final demoWeights = store.demoRecordCounts[RecordCategory.body] ?? 0;
      expect(demoWeights, greaterThan(0), reason: 'the seed is demo data');
      expect(store.typedRecordCounts, isEmpty, reason: 'nothing typed yet');

      store.backend.journal.recordWeight(80.1);
      expect(store.typedRecordCounts[RecordCategory.body], 1);
      expect(
        store.demoRecordCounts[RecordCategory.body],
        demoWeights,
        reason: 'what the user typed is never counted as demo',
      );
      expect(store.imports, isEmpty);
    });
  });

  group('journal corrections', () {
    test('a weight is corrected in place, audited, and keeps its day', () {
      final clock = FakeClock();
      final backend = Backend.inMemory(clock: clock.now);
      addTearDown(backend.close);
      final weight = backend.journal.recordWeight(81.2);
      clock.advance(const Duration(days: 2));

      backend.journal.updateWeight(
        BodyWeight(
          id: weight.id,
          measuredAt: weight.measuredAt,
          weightKg: 80.2,
          note: weight.note,
        ),
      );

      final stored = backend.journal.entry(weight.id)! as BodyWeight;
      expect(stored.weightKg, 80.2);
      expect(
        stored.measuredAt,
        weight.measuredAt,
        reason: 'correcting the number does not move the reading',
      );
      final audit = backend.db.select(
        "SELECT payload FROM audit_events WHERE entity_id = ? "
        "AND action = 'edit'",
        [weight.id],
      );
      expect(
        audit.single['payload'],
        contains('81.2'),
        reason: 'what it replaced is kept',
      );
    });

    test('deleting is a tombstone, and restoring brings it back', () {
      final backend = Backend.inMemory(clock: FakeClock().now);
      addTearDown(backend.close);
      final night = backend.journal.recordSleep(const Duration(hours: 7));

      backend.journal.delete(night.id);
      expect(backend.journal.entry(night.id), isNull);
      expect(
        backend.db.select('SELECT 1 FROM sleep_entries WHERE id = ?', [
          night.id,
        ]),
        hasLength(1),
        reason: 'nothing is hard deleted',
      );

      backend.journal.restore(night.id);
      expect(backend.journal.entry(night.id), isA<SleepEntry>());
      expect(backend.journal.sourceOf(night.id), ChangeSource.local);
    });
  });

  group('canonical archive', () {
    test('export → restore into an empty store → export is lossless', () {
      final source = AppStore(clock: clock.now, isOnboarded: true)
        ..startWorkout()
        ..completeNextSet()
        ..confirmLunch();
      addTearDown(source.dispose);
      final split = NutritionViewModel(source.backend);
      addTearDown(split.dispose);
      split.splitDish(mealId: 'lunch', dishIndex: 0, day: clock.now());
      source
        ..backend.nutrition.saveFood(
          FoodItem(
            id: source.backend.nutrition.newFoodId(),
            name: '雞胸肉',
            brand: '大成',
            servingLabel: '一片',
            servingAmount: 100,
            servingUnit: ServingUnit.gram,
            kcal: 165,
            proteinGrams: 31.4,
            carbGrams: 0,
            fatGrams: 4,
            nutrients: const {Nutrient.sodium: 74},
          ),
        )
        // A bottle whose caffeine was typed per 100 ml.
        ..backend.nutrition.saveFood(
          FoodItem(
            id: source.backend.nutrition.newFoodId(),
            name: '無糖紅茶',
            servingAmount: 600,
            servingUnit: ServingUnit.millilitre,
            kind: ConsumptionKind.beverage,
            caffeineBasis: CaffeineBasis.per100,
            nutrients: const {Nutrient.caffeine: 120},
          ),
        );
      final archive = exportArchive(source.backend.db);

      final target = Backend.inMemory(clock: clock.now);
      addTearDown(target.close);
      restoreArchive(target.db, jsonDecode(encodeArchive(archive)));
      final roundTripped = exportArchive(target.db);

      expect(roundTripped, archive);
      final restoredStore = AppStore(clock: clock.now, backend: target);
      expect(restoredStore.activeWorkout!.completedSets, 1);
      expect(restoredStore.todayMeals, hasLength(2));
      expect(
        restoredStore.backend.nutrition.searchFoods('雞胸').single.kcal,
        165,
      );
      expect(
        restoredStore.backend.nutrition
            .searchFoods('無糖紅茶')
            .single
            .caffeineBasis,
        CaffeineBasis.per100,
      );
      expect(
        restoredStore.backend.nutrition
            .searchFoods('雞胸')
            .single
            .nutrients[Nutrient.sodium],
        74,
      );
    });

    test('the JSON Schema describes the archive it ships with', () {
      final schema = archiveJsonSchema();
      final source = AppStore(clock: clock.now, isOnboarded: true)
        ..startWorkout()
        ..completeNextSet()
        ..confirmLunch();
      addTearDown(source.dispose);
      final archive = jsonDecode(
        encodeArchive(exportArchive(source.backend.db)),
      );

      final properties =
          (schema['properties']! as Map)['data']! as Map<String, Object?>;
      final tables = (properties['properties']! as Map).keys.toSet();
      expect(
        (archive as Map)['data'],
        isA<Map<String, Object?>>().having(
          (data) => data.keys.toSet(),
          'sections',
          tables,
        ),
        reason:
            'the schema is generated from the same table list, so a '
            'section missing from either side is a drift bug',
      );

      // Every non-null column is required, and a nullable one admits null.
      final foods =
          ((properties['properties']! as Map)['foods']! as Map)['items']!
              as Map<String, Object?>;
      expect(foods['required'], contains('id'));
      expect(foods['required'], isNot(contains('kcal')));
      // A label prints 274.4 kcal, so a food's figures are numbers.
      expect(((foods['properties']! as Map)['kcal']! as Map)['type'], [
        'number',
        'null',
      ]);
      expect(
        ((foods['properties']! as Map)['createdAt']! as Map)['format'],
        'date-time',
      );

      // Kept on disk so anyone reading a backup has the contract without
      // running the app. Regenerated here, so it cannot go stale.
      File('doc/archive.schema.json').writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(schema)}\n',
      );
    });

    test('a secret never travels in a backup', () {
      final backend = Backend.inMemory(clock: clock.now);
      addTearDown(backend.close);
      backend.db.setSetting('glass_millilitres', '350');
      backend.db.setSetting(
        '${AppDatabase.secretKeyPrefix}openai_api_key',
        'a-key-that-must-stay-on-the-device',
      );

      final archive = encodeArchive(exportArchive(backend.db));

      expect(
        archive,
        contains('glass_millilitres'),
        reason: 'ordinary settings still belong in a backup',
      );
      expect(
        archive,
        isNot(contains('a-key-that-must-stay-on-the-device')),
        reason:
            'the settings table is written into the archive whole, so '
            'a key pasted in by the user would otherwise travel in every '
            'backup they email themselves',
      );
      // The audit trail still says a secret was set, by name: that a
      // setting changed is history, and the name is not the secret.
      expect(
        archive,
        isNot(contains('"key": "${AppDatabase.secretKeyPrefix}')),
        reason: 'no settings row for it either',
      );
      expect(
        backend.db.setting('${AppDatabase.secretKeyPrefix}openai_api_key'),
        'a-key-that-must-stay-on-the-device',
        reason: 'it is kept, just never exported',
      );

      // And because it is not in the file, a restore must not treat its
      // absence as a deletion.
      restoreArchive(backend.db, jsonDecode(archive));
      expect(
        backend.db.setting('${AppDatabase.secretKeyPrefix}openai_api_key'),
        'a-key-that-must-stay-on-the-device',
        reason:
            'restoring your own backup must not sign you out of your '
            'AI provider',
      );
      expect(
        backend.db.setting('glass_millilitres'),
        '350',
        reason: 'ordinary settings still come back from the file',
      );
    });

    test('unknown archive sections are kept for the next export', () {
      final source = Backend.inMemory(clock: clock.now);
      addTearDown(source.close);
      final archive = exportArchive(source.db)
        ..['extensions'] = {
          'com.example.sleep': {'nights': 3},
        };

      restoreArchive(source.db, archive);

      expect(exportArchive(source.db)['extensions'], {
        'com.example.sleep': {'nights': 3},
      });
    });

    test('a broken or newer archive is refused and changes nothing', () {
      final store = AppStore(clock: clock.now, isOnboarded: true);
      addTearDown(store.dispose);
      final before = exportArchive(store.backend.db);

      final broken = jsonDecode(encodeArchive(before)) as Map<String, Object?>;
      ((broken['data']! as Map)['workoutSets'] as List).add({'reps': 'five'});
      expect(
        () => restoreArchive(store.backend.db, broken),
        throwsA(isA<ArchiveFormatException>()),
      );
      expect(
        () => restoreArchive(store.backend.db, {
          ...before,
          'formatVersion': archiveFormatVersion + 1,
        }),
        throwsA(isA<ArchiveFormatException>()),
      );
      expect(
        () => restoreArchive(store.backend.db, 'not an archive'),
        throwsA(isA<ArchiveFormatException>()),
      );

      expect(exportArchive(store.backend.db), before);
    });
  });

  group('csv', () {
    test('quotes only what needs it and parses back', () {
      final rows = [
        ['name', 'note'],
        ['臥推', 'a "tight", arch\nnext'],
      ];

      final text = encodeCsv(rows);
      expect(text, 'name,note\r\n臥推,"a ""tight"", arch\nnext"');
      expect(parseCsv(text), rows);
    });

    test('views list finished sets, meals and weights', () {
      final store = AppStore(clock: clock.now, isOnboarded: true);
      addTearDown(store.dispose);
      final views = exportCsvViews(store.backend.db);

      final sets = parseCsv(views['workouts.csv']!);
      expect(sets.first.first, 'date');
      expect(sets.where((row) => row[2] == '槓鈴深蹲').last.sublist(3, 7), [
        '3',
        'working',
        '95.0',
        '5',
      ]);
      expect(parseCsv(views['meals.csv']!).last[1], '早餐');
      expect(parseCsv(views['body_weights.csv']!).last[1], '72.4');
    });
  });
}
