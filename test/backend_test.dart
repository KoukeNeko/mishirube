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
import 'package:mishirube/backend/engines/training_metrics.dart';
import 'package:mishirube/domain/domain.dart';
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
      final september = store.monthRecords(DateTime(2026, 9));
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
      final workouts = store
          .monthRecords(DateTime(2026, 9))
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
        store
            .monthRecords(DateTime(2026, 9))
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
      expect(store.isGoalEnabled, isFalse, reason: 'nothing set by default');
      expect(store.goalOverview.hasGoal, isFalse);

      store.setWeeklyGoal(4, applyThisWeek: true);
      store.pauseGoal();

      final reopened = AppStore(clock: clock.now, backend: backend);
      expect(reopened.isGoalEnabled, isTrue);
      expect(reopened.goalOverview.thisWeek.targetDays, 4);
      expect(reopened.goalOverview.isPaused, isTrue);

      reopened.resumeGoal();
      expect(
        AppStore(clock: clock.now, backend: backend).goalOverview.isPaused,
        isFalse,
      );
    });

    test('a day with a workout and a run counts once', () {
      final store = AppStore(clock: clock.now, isOnboarded: true)
        ..setWeeklyGoal(5, applyThisWeek: true);
      addTearDown(store.dispose);
      final before = store.goalOverview.thisWeek.activeDays;

      store
        ..logActivity(
          type: ActivityTypes.running,
          startedAt: clock.now(),
          duration: const Duration(minutes: 30),
        )
        ..logActivity(
          type: ActivityTypes.cycling,
          startedAt: clock.now().subtract(const Duration(hours: 3)),
          duration: const Duration(minutes: 40),
        );

      expect(
        store.goalOverview.thisWeek.activeDays,
        before + 1,
        reason: 'two records on one day are still one active day',
      );
    });

    test('a late record brings the week, and the run, back', () {
      final store = AppStore(clock: clock.now, isOnboarded: true)
        ..setWeeklyGoal(3, applyThisWeek: true);
      addTearDown(store.dispose);
      final short = store.goalOverview.weeks.lastWhere(
        (week) => !week.isCurrent && !week.isMet && !week.isPaused,
      );
      final before = store.goalOverview.streak;

      // Fill that week in, as if catching up on records.
      for (var i = 0; i < short.targetDays - short.activeDays; i++) {
        store.logActivity(
          type: ActivityTypes.walking,
          startedAt: short.start.add(Duration(days: i, hours: 9)),
          duration: const Duration(minutes: 30),
        );
      }

      final after = store.goalOverview;
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
    test('an exploded dish and its undo are both stored', () {
      final backend = openFile();
      addTearDown(backend.close);
      final store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: backend,
      )..confirmLunch();
      final lunchDishes = store.todayMeals.last.dishes.length;

      final snapshot = store.splitDish(mealId: 'lunch', dishIndex: 0)!;
      final exploded = AppStore(clock: clock.now, backend: backend);
      expect(exploded.todayMeals.last.dishes, hasLength(lunchDishes + 4));

      store.undoSplit(snapshot);
      final restored = AppStore(clock: clock.now, backend: backend);
      expect(restored.todayMeals.last.dishes, hasLength(lunchDishes));
      expect(restored.todayMeals.last.dishes.first.components, hasLength(5));
    });

    test('recent meals come from the records and can be logged again', () {
      final store = AppStore(clock: clock.now, isOnboarded: true);
      addTearDown(store.dispose);

      final recent = store.recentMeals;
      expect(recent, hasLength(3));
      expect(recent.first.eatenAt.isAfter(recent.last.eatenAt), isTrue);
      expect(
        recent.map((meal) => meal.label).toSet(),
        hasLength(3),
        reason: 'the same dish is offered once, not once per day',
      );

      final before = store.todayKcal;
      final again = store.copyMeal(recent.first.meal);

      expect(store.todayMeals.last.id, again.id);
      expect(store.todayKcal, before + recent.first.meal.kcal);
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
      final meals = store.mealsOn(yesterday);
      final summary = store.summaryOf(yesterday);

      expect(meals, hasLength(1));
      expect(summary.mealCount, 1);
      expect(summary.isComplete, isFalse, reason: 'only one meal that day');

      final snapshot = store.splitDish(
        mealId: meals.single.id,
        dishIndex: 0,
        day: yesterday,
      )!;
      expect(
        AppStore(
          clock: clock.now,
          backend: backend,
        ).mealsOn(yesterday).single.dishes,
        hasLength(5),
      );
      expect(store.todayMeals, hasLength(1), reason: 'today is untouched');

      store.undoSplit(snapshot);
      expect(store.mealsOn(yesterday).single.dishes, hasLength(1));
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
      store.logActivity(
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

      final entries = reopened
          .monthRecords(DateTime(2026, 9))
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
      final logged = store.logActivity(
        type: ActivityTypes.running,
        startedAt: clock.now().subtract(const Duration(minutes: 30)),
        duration: const Duration(minutes: 30),
        distanceMeters: 5000,
      );

      store.updateActivity(
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
      ).activityById(logged.id)!;
      expect(corrected.type, ActivityTypes.cycling);
      expect(corrected.duration, const Duration(minutes: 55));

      store.deleteActivity(logged.id);
      expect(store.activityById(logged.id), isNull);
      expect(
        store.activitiesOn(clock.now()).map((session) => session.id),
        isNot(contains(logged.id)),
      );

      store.restoreActivity(logged.id);
      expect(store.activityById(logged.id), isNotNull);
      expect(
        AppStore(clock: clock.now, backend: backend).activityById(logged.id),
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
        ).activityById(finished.id)?.duration,
        const Duration(minutes: 12),
        reason: 'the paused five minutes are not exercise',
      );
    });

    test('a discarded session leaves no record behind', () {
      final store = AppStore(clock: clock.now, isOnboarded: true);
      addTearDown(store.dispose);
      final before = store.activitySummary().sessions;

      store.startActivity(ActivityTypes.swimming);
      clock.advance(const Duration(minutes: 20));
      store.discardActivity();

      expect(store.activeSession, isNull);
      expect(store.activitySummary().sessions, before);
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

      final summary = store.activitySummary();
      expect(summary.hasRecords, isTrue);
      expect(summary.thisWeek, 2, reason: 'the two sessions since Monday');
      expect(summary.weekly, hasLength(4));
      expect(summary.minutesThisWeek, 82, reason: 'the ride and the run');
      expect(
        summary.typicalWeeklyMinutes,
        isNotNull,
        reason: 'three finished weeks are enough for a normal week',
      );
      final workouts = store.trends().workoutsThisWeek;
      store.logActivity(
        type: ActivityTypes.swimming,
        startedAt: clock.now().subtract(const Duration(minutes: 45)),
        duration: const Duration(minutes: 45),
      );
      expect(store.activitySummary().thisWeek, summary.thisWeek + 1);
      expect(
        store.trends().workoutsThisWeek,
        workouts,
        reason: 'a swim is not a workout',
      );
    });

    test('the form starts from what was done last', () {
      final store = AppStore(clock: clock.now, isOnboarded: true);
      addTearDown(store.dispose);

      expect(store.recentActivityTypes.first, ActivityTypes.cycling);
      expect(
        store.startingActivityDuration(ActivityTypes.running),
        const Duration(minutes: 32),
      );
      expect(
        store.startingActivityDuration(ActivityTypes.badminton),
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
      final september = store.monthRecords(DateTime(2026, 9));

      final today = september.days.first;
      expect(today.label, '今天 · 9 月 19 日（週六）');
      expect(today.warning, isNull, reason: 'today is not over yet');
      expect(today.entries.map((e) => e.title), ['早餐', '體重 72.4 kg']);

      final yesterday = september.days[1];
      expect(yesterday.warning, '飲食紀錄不完整');
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

      final entry = store
          .monthRecords(DateTime(2026, 9))
          .days
          .first
          .entries
          .first;
      expect(entry.category, RecordCategory.training);
      expect(entry.detail, '4 組 · 58 分 · 槓鈴深蹲 100 kg × 5 為新紀錄');
    });
  });

  group('canonical archive', () {
    test('export → restore into an empty store → export is lossless', () {
      final source = AppStore(clock: clock.now, isOnboarded: true)
        ..startWorkout()
        ..completeNextSet()
        ..confirmLunch();
      addTearDown(source.dispose);
      source.splitDish(mealId: 'lunch', dishIndex: 0);
      final archive = exportArchive(source.backend.db);

      final target = Backend.inMemory(clock: clock.now);
      addTearDown(target.close);
      restoreArchive(target.db, jsonDecode(encodeArchive(archive)));
      final roundTripped = exportArchive(target.db);

      expect(roundTripped, archive);
      final restoredStore = AppStore(clock: clock.now, backend: target);
      expect(restoredStore.activeWorkout!.completedSets, 1);
      expect(restoredStore.todayMeals, hasLength(2));
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
