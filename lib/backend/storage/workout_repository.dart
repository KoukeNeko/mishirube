import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../engines/training_metrics.dart';
import 'database.dart';
import 'exercise_repository.dart';
import 'timeline_source.dart';

typedef ExerciseResolver = ExerciseDefinition Function(String id);

/// Workouts as they actually happened (the actual side of training).
///
/// A running workout is stored like a finished one, with status
/// `in_progress`; each set is committed when it is logged, so the workout
/// is restored as it was if the app is killed.
class WorkoutRepository {
  WorkoutRepository(this._db);

  final AppDatabase _db;

  WorkoutSession? active(ExerciseResolver exercises) {
    final rows = _db.select(
      "SELECT id FROM workouts WHERE status = 'in_progress' "
      'AND deleted_at IS NULL',
    );
    return rows.isEmpty ? null : byId(rows.first['id'], exercises);
  }

  WorkoutSession? lastFinished(ExerciseResolver exercises) {
    final rows = _db.select(
      "SELECT id FROM workouts WHERE status = 'completed' "
      'AND deleted_at IS NULL ORDER BY finished_at DESC LIMIT 1',
    );
    return rows.isEmpty ? null : byId(rows.first['id'], exercises);
  }

  /// When each finished workout started, oldest first.
  List<DateTime> completedStarts({DateTime? since}) => [
    for (final row in _db.select(
      "SELECT started_at FROM workouts WHERE status = 'completed' "
      'AND deleted_at IS NULL AND started_at >= ? ORDER BY started_at',
      [since?.millisecondsSinceEpoch ?? 0],
    ))
      DateTime.fromMillisecondsSinceEpoch(row['started_at']),
  ];

  /// Whether a live workout was already imported with [fingerprint].
  bool hasFingerprint(String fingerprint) => _db.select(
    'SELECT 1 FROM workouts WHERE fingerprint = ? AND deleted_at IS NULL',
    [fingerprint],
  ).isNotEmpty;

  WorkoutSession? byId(String id, ExerciseResolver exercises) {
    final rows = _db.select('SELECT * FROM workouts WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final sets = _db.select(
      'SELECT * FROM workout_sets WHERE workout_id = ? '
      'ORDER BY exercise_position, position',
      [id],
    );
    final exerciseRows = _db.select(
      'SELECT * FROM workout_exercises WHERE workout_id = ? ORDER BY position',
      [id],
    );
    return WorkoutSession(
        id: id,
        routineId: row['routine_id'],
        routineName: row['name'],
        notes: row['notes'],
        startedAt: _time(row['started_at'])!,
        exercises: [
          for (final exercise in exerciseRows)
            ExerciseSession(
              exercise: exercises(exercise['exercise_id']),
              isPersonalRecordCandidate: exercise['is_pr_candidate'] == 1,
              sets: [
                for (final set in sets)
                  if (set['exercise_position'] == exercise['position'])
                    _setFromRow(set),
              ],
            ),
        ],
      )
      ..currentExerciseIndex = row['current_exercise']
      ..finishedAt = _time(row['finished_at'])
      ..pausedAt = _time(row['paused_at'])
      ..pausedTotal = Duration(milliseconds: row['paused_total_ms']);
  }

  /// Abandons a running workout. The row stays with status `cancelled`,
  /// so nothing counts it as training done, but the audit trail still
  /// shows it happened.
  void cancel(WorkoutSession workout) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        "UPDATE workouts SET status = 'cancelled', finished_at = ?, "
        'updated_at = ?, revision = revision + 1 WHERE id = ?',
        [now, now, workout.id],
      );
      _db.audit(entityType: 'workout', entityId: workout.id, action: 'discard');
    });
  }

  /// Writes the whole workout. [action] names what changed for the audit
  /// log (e.g. `start`, `complete_set`, `finish`).
  void save(
    WorkoutSession workout, {
    required String action,
    ChangeSource source = ChangeSource.local,
    String? importBatchId,
    String? fingerprint,
  }) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      final status = workout.finishedAt == null ? 'in_progress' : 'completed';
      final exists = _db.select('SELECT 1 FROM workouts WHERE id = ?', [
        workout.id,
      ]).isNotEmpty;
      final values = [
        workout.routineId,
        workout.routineName,
        status,
        workout.startedAt.millisecondsSinceEpoch,
        workout.finishedAt?.millisecondsSinceEpoch,
        workout.pausedAt?.millisecondsSinceEpoch,
        workout.pausedTotal.inMilliseconds,
        workout.currentExerciseIndex,
        workout.notes,
      ];
      if (exists) {
        _db.execute(
          'UPDATE workouts SET routine_id = ?, name = ?, status = ?, '
          'started_at = ?, finished_at = ?, paused_at = ?, '
          'paused_total_ms = ?, current_exercise = ?, notes = ?, '
          'updated_at = ?, '
          'revision = revision + 1 WHERE id = ?',
          [...values, now, workout.id],
        );
        _db.execute('DELETE FROM workout_sets WHERE workout_id = ?', [
          workout.id,
        ]);
        _db.execute('DELETE FROM workout_exercises WHERE workout_id = ?', [
          workout.id,
        ]);
      } else {
        _db.execute(
          'INSERT INTO workouts (routine_id, name, status, started_at, '
          'finished_at, paused_at, paused_total_ms, current_exercise, notes, '
          'id, created_at, updated_at, source, import_batch_id, fingerprint, '
          'local_day, utc_offset_minutes) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            ...values,
            workout.id,
            now,
            now,
            source.name,
            importBatchId,
            fingerprint,
            localDayOf(workout.startedAt),
            workout.startedAt.timeZoneOffset.inMinutes,
          ],
        );
      }
      for (final (position, exercise) in workout.exercises.indexed) {
        _db.execute(
          'INSERT INTO workout_exercises (workout_id, position, exercise_id, '
          'exercise_name, is_pr_candidate) VALUES (?, ?, ?, ?, ?)',
          [
            workout.id,
            position,
            exercise.exercise.id,
            exercise.exercise.name,
            exercise.isPersonalRecordCandidate ? 1 : 0,
          ],
        );
        for (final (setPosition, set) in exercise.sets.indexed) {
          _db.execute(
            'INSERT INTO workout_sets (workout_id, exercise_position, '
            'position, set_type, weight_kg, reps, rir, rpe, duration_s, '
            'distance_m, previous_weight_kg, previous_reps, is_done) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              workout.id,
              position,
              setPosition,
              set.type.name,
              set.weightKg,
              set.reps,
              set.rir,
              set.rpe,
              set.durationSeconds,
              set.distanceMeters,
              set.previousWeightKg,
              set.previousReps,
              set.isDone ? 1 : 0,
            ],
          );
        }
      }
      _db.audit(
        entityType: 'workout',
        entityId: workout.id,
        action: action,
        source: source,
        importBatchId: importBatchId,
      );
    });
  }

  WorkoutSet _setFromRow(Map<String, Object?> row) {
    final weight = (row['weight_kg']! as num).toDouble();
    final reps = row['reps']! as int;
    return WorkoutSet(
      weightKg: weight,
      reps: reps,
      previousWeightKg:
          (row['previous_weight_kg'] as num?)?.toDouble() ?? weight,
      previousReps: row['previous_reps'] as int? ?? reps,
      rir: row['rir'] as int?,
      rpe: (row['rpe'] as num?)?.toDouble(),
      type: SetType.values.byName(row['set_type']! as String),
      durationSeconds: row['duration_s'] as int?,
      distanceMeters: (row['distance_m'] as num?)?.toDouble(),
      isDone: row['is_done'] == 1,
    );
  }
}

DateTime? _time(Object? millis) =>
    millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis as int);

/// Finished workouts as log rows.
class WorkoutTimelineSource extends TimelineSource {
  WorkoutTimelineSource(this._workouts, this._exercises);

  final WorkoutRepository _workouts;
  final ExerciseRepository _exercises;

  AppDatabase get _db => _workouts._db;

  @override
  RecordCategory get category => RecordCategory.training;

  @override
  DateTime? earliest() {
    final first = _db
        .select(
          "SELECT MIN(started_at) AS first FROM workouts "
          "WHERE status = 'completed' AND deleted_at IS NULL",
        )
        .first['first'];
    return first == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(first as int);
  }

  @override
  List<(DateTime, TimelineEntry)> entriesIn(DateTime start, DateTime end) {
    // One lookup per exercise per month, not per set.
    final known = <String, ExerciseDefinition>{};
    ExerciseDefinition resolve(String id) => known[id] ??= _exercises.byId(id)!;
    return [
      for (final (_, offset, workout) in _completed(start, end, resolve))
        (
          asLived(workout.finishedAt!, offset),
          TimelineEntry(
            timeLabel: formatTimeOfDay(asLived(workout.finishedAt!, offset)),
            at: asLived(workout.finishedAt!, offset),
            recordId: workout.id,
            category: RecordCategory.training,
            title: workout.routineName,
            detail: [
              '${workout.completedSets} 組',
              '${workout.elapsedAt(workout.finishedAt!).inMinutes} 分',
              ?_personalRecord(workout),
            ].join(' · '),
          ),
        ),
    ];
  }

  @override
  Map<int, String> summariesIn(DateTime start, DateTime end) => {
    for (final (day, _, workout) in _completed(
      start,
      end,
      (id) => _exercises.byId(id)!,
    ))
      day % 100: '${workout.routineName} · ${workout.completedSets} 組',
  };

  /// Finished workouts of the month, each with the day it was trained on
  /// and the offset it was trained in.
  List<(int, int?, WorkoutSession)> _completed(
    DateTime start,
    DateTime end,
    ExerciseResolver exercises,
  ) => [
    for (final row in _db.select(
      'SELECT id, utc_offset_minutes, '
      '${AppDatabase.localDaySql('started_at')} AS day FROM workouts '
      "WHERE status = 'completed' AND deleted_at IS NULL "
      'AND day BETWEEN ? AND ? ORDER BY started_at',
      [localDayOf(start), localDayOf(end.subtract(const Duration(days: 1)))],
    ))
      (
        row['day']! as int,
        row['utc_offset_minutes'] as int?,
        _workouts.byId(row['id'], exercises)!,
      ),
  ];

  /// A heavier set than any earlier finished session of the same exercise.
  String? _personalRecord(WorkoutSession workout) {
    for (final session in workout.exercises) {
      final best = heaviestSet(session.sets);
      if (best == null) continue;
      final rows = _db.select(
        '''
        SELECT MAX(s.weight_kg) AS best FROM workout_sets s
        JOIN workout_exercises we ON we.workout_id = s.workout_id
          AND we.position = s.exercise_position
        JOIN workouts w ON w.id = s.workout_id
        WHERE we.exercise_id = ? AND w.status = 'completed'
          AND w.deleted_at IS NULL AND w.started_at < ? AND s.is_done = 1
          AND s.set_type != 'warmup'
        ''',
        [session.exercise.id, workout.startedAt.millisecondsSinceEpoch],
      );
      final previousBest = (rows.first['best'] as num?)?.toDouble();
      if (previousBest != null && best.weightKg > previousBest) {
        return '${session.exercise.name} ${formatWeight(best.weightKg)} kg × '
            '${best.reps} 為新紀錄';
      }
    }
    return null;
  }
}
