import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
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
