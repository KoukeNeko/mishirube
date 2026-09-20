import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/import_export/strong_import.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/seed/seed.dart';
import 'package:mishirube/domain/domain.dart';

import 'support/harness.dart';

const _currentHeader =
    '"Workout #";"Date";"Workout Name";"Duration (sec)";"Exercise Name";'
    '"Set Order";"Weight (kg)";"Reps";"RPE";"Distance (meters)";"Seconds";'
    '"Notes";"Workout Notes"';

String _row(List<Object> fields) => fields.map((f) => '"$f"').join(';');

/// Strong 6.2.3+ layout: two workouts, warm-up and drop sets, a rest timer,
/// a timed exercise and one exercise the catalog does not know.
final _currentExport = [
  _currentHeader,
  _row([
    1,
    '2026-08-01 09:00:00',
    'Legs',
    3480,
    'Squat (Barbell)',
    'W',
    40,
    8,
    '',
    '',
    '',
    '',
    'felt good',
  ]),
  _row([
    1,
    '2026-08-01 09:00:00',
    'Legs',
    3480,
    'Squat (Barbell)',
    1,
    90,
    5,
    8,
    '',
    '',
    'belt',
    'felt good',
  ]),
  _row([
    1,
    '2026-08-01 09:00:00',
    'Legs',
    3480,
    'Squat (Barbell)',
    'Rest Timer',
    0,
    0,
    '',
    '',
    180,
    '',
    '',
  ]),
  _row([
    1,
    '2026-08-01 09:00:00',
    'Legs',
    3480,
    'Squat (Barbell)',
    2,
    90,
    5,
    12,
    '',
    '',
    '',
    '',
  ]),
  _row([
    1,
    '2026-08-01 09:00:00',
    'Legs',
    3480,
    'Nordic Curl',
    1,
    0,
    6,
    '',
    '',
    '',
    '',
    '',
  ]),
  _row([
    2,
    '2026-08-03 18:00:00',
    'Push',
    2700,
    'Bench Press (Barbell)',
    1,
    70,
    5,
    '',
    '',
    '',
    '',
    '',
  ]),
  _row([
    2,
    '2026-08-03 18:00:00',
    'Push',
    2700,
    'Bench Press (Barbell)',
    'D',
    50,
    10,
    '',
    '',
    '',
    '',
    '',
  ]),
  _row([
    2,
    '2026-08-03 18:00:00',
    'Push',
    2700,
    'Plank',
    1,
    0,
    0,
    '',
    '',
    60,
    '',
    '',
  ]),
].join('\n');

/// The same history exported later, with one more workout.
final _laterExport = [
  _currentExport,
  _row([
    3,
    '2026-08-05 18:00:00',
    'Legs',
    3000,
    'Squat (Barbell)',
    1,
    92.5,
    5,
    '',
    '',
    '',
    '',
    '',
  ]),
].join('\n');

/// The older comma layout with `1h 5m` durations and unlabelled weights.
const _legacyExport = '''
Date,Workout Name,Duration,Exercise Name,Set Order,Weight,Reps,Distance,Seconds,Notes,Workout Notes,RPE
2025-03-02 07:05:00,Morning,1h 5m,Deadlift (Barbell),1,225,5,0,0,,,
2025-03-02 07:05:00,Morning,1h 5m,Deadlift (Barbell),2,225,5,0,0,,,
02/03/2025,Morning,1h 5m,Deadlift (Barbell),3,225,5,0,0,,,
2025-03-02 07:05:00,Morning,1h 5m,Deadlift (Barbell),X,225,5,0,0,,,
''';

void main() {
  late FakeClock clock;
  late Backend backend;
  late StrongImporter importer;

  setUp(() {
    clock = FakeClock();
    backend = Backend.inMemory(clock: clock.now);
    seedDemoData(backend, clock.now());
    importer = StrongImporter(backend);
  });

  tearDown(() => backend.close());

  int liveWorkouts() =>
      backend.db
              .select(
                "SELECT COUNT(*) AS n FROM workouts WHERE source = 'strongImport' "
                'AND deleted_at IS NULL',
              )
              .first['n']
          as int;

  test('a dry run reports the current format without writing', () {
    final auditBefore = backend.db
        .select('SELECT COUNT(*) AS n FROM audit_events')
        .first['n'];

    final plan = importer.dryRun(_currentExport, fileName: 'strong.csv');

    expect(plan.dialect, StrongDialect.current);
    expect(plan.rowsRead, 8);
    expect(plan.restTimerRows, 1);
    expect(plan.newWorkouts, 2);
    expect(plan.newSets, 7);
    expect(plan.setsOfType(SetType.warmup), 1);
    expect(plan.setsOfType(SetType.drop), 1);
    expect(plan.issues.single.row, 4, reason: 'RPE 12 is out of range');
    expect(plan.issues.single.isSkipped, isFalse);
    expect(plan.exercises['Squat (Barbell)']!.exercise.id, 'back-squat');
    expect(plan.exercises['Bench Press (Barbell)']!.exercise.id, 'bench-press');
    expect(plan.exercises['Plank']!.exercise.id, 'plank');
    final nordic = plan.exercises['Nordic Curl']!;
    expect(nordic.kind, ExerciseMatchKind.created);
    expect(nordic.exercise.trackingType, TrackingType.reps);
    expect(liveWorkouts(), 0);
    expect(
      backend.db.select('SELECT COUNT(*) AS n FROM audit_events').first['n'],
      auditBefore,
    );
  });

  test('commit writes one batch with sets, notes and new exercises', () {
    final result = importer.commit(
      importer.dryRun(_currentExport, fileName: 'strong.csv'),
    );

    expect(result.workouts, 2);
    expect(result.sets, 7);
    expect(result.exercisesCreated, 1);
    final legs = backend.db
        .select(
          "SELECT * FROM workouts WHERE name = 'Legs' AND deleted_at IS NULL",
        )
        .single;
    expect(legs['import_batch_id'], result.batchId);
    expect(legs['notes'], 'felt good\nSquat (Barbell)：belt');
    expect(
      legs['finished_at'] - legs['started_at'],
      const Duration(seconds: 3480).inMilliseconds,
    );
    final squat = backend.storage.exercises.history('back-squat');
    expect(
      squat.recent.map((entry) => entry.date),
      contains(DateTime(2026, 8, 1, 9)),
    );
    final rpe = backend.db.select(
      'SELECT rpe FROM workout_sets WHERE workout_id = ? '
      'AND exercise_position = 0 ORDER BY position',
      [legs['id']],
    );
    expect(rpe.map((row) => row['rpe']), [null, 8.0, null]);
  });

  test('importing the same file again is refused', () {
    importer.commit(importer.dryRun(_currentExport, fileName: 'strong.csv'));

    final again = importer.dryRun(_currentExport, fileName: 'strong.csv');

    expect(again.isAlreadyImported, isTrue);
    expect(again.newWorkouts, 0);
    expect(() => importer.commit(again), throwsStateError);
    expect(liveWorkouts(), 2);
  });

  test('an overlapping later export only adds what is new', () {
    importer.commit(importer.dryRun(_currentExport, fileName: 'a.csv'));

    final later = importer.dryRun(_laterExport, fileName: 'b.csv');
    expect(later.duplicateWorkouts, 2);
    expect(later.newWorkouts, 1);
    expect(later.exercises['Nordic Curl']!.kind, ExerciseMatchKind.remembered);
    importer.commit(later);

    expect(liveWorkouts(), 3);
  });

  test('undo takes the batch back and the file can be imported again', () {
    final first = importer.commit(
      importer.dryRun(_currentExport, fileName: 'strong.csv'),
    );

    importer.undo(first.batchId);

    expect(liveWorkouts(), 0);
    expect(
      backend.storage.exercises.all().map((e) => e.name),
      isNot(contains('Nordic Curl')),
    );
    final retry = importer.dryRun(_currentExport, fileName: 'strong.csv');
    expect(retry.isAlreadyImported, isFalse);
    expect(retry.newWorkouts, 2);
    importer.commit(retry);
    expect(liveWorkouts(), 2);
    expect(
      backend.storage.exercises.all().map((e) => e.name),
      contains('Nordic Curl'),
    );
  });

  test('the legacy format converts pounds and reports unreadable rows', () {
    final plan = importer.dryRun(
      _legacyExport,
      fileName: 'old.csv',
      legacyWeightUnit: WeightUnit.lb,
    );

    expect(plan.dialect, StrongDialect.legacy);
    expect(plan.newWorkouts, 1);
    expect(plan.newSets, 2);
    final skipped = plan.issues.where((issue) => issue.isSkipped).toList();
    expect(skipped.map((issue) => issue.row), [3, 4]);
    expect(skipped.first.message, contains('日期格式無法解析'));
    expect(skipped.last.message, contains('「X」'));

    final result = importer.commit(plan);
    final sets = backend.db.select(
      'SELECT s.weight_kg FROM workout_sets s JOIN workouts w '
      'ON w.id = s.workout_id WHERE w.import_batch_id = ?',
      [result.batchId],
    );
    expect(sets.map((row) => row['weight_kg']), [102.06, 102.06]);
    final workout = backend.db.select(
      'SELECT started_at, finished_at FROM workouts WHERE import_batch_id = ?',
      [result.batchId],
    ).single;
    expect(
      workout['finished_at'] - workout['started_at'],
      const Duration(hours: 1, minutes: 5).inMilliseconds,
    );
  });

  test('a file that is not a Strong export is rejected', () {
    expect(
      () => importer.dryRun('a,b,c\n1,2,3', fileName: 'other.csv'),
      throwsA(isA<StrongFormatException>()),
    );
  });
}
