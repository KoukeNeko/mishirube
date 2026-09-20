import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../domain/domain.dart';
import '../../shared/format.dart';
import 'database.dart';
import '../engines/training_metrics.dart';

/// The exercise catalog: built-in, custom and imported definitions. Usage
/// figures (last performance, record count) are derived from finished
/// workouts, never stored on the definition.
class ExerciseRepository {
  ExerciseRepository(this._db);

  final AppDatabase _db;

  /// Every live exercise, with usage as of the database clock.
  List<ExerciseDefinition> all() {
    final rows = _db.select(
      'SELECT * FROM exercises WHERE deleted_at IS NULL ORDER BY rowid',
    );
    return [for (final row in rows) _fromRow(row, history(row['id']))];
  }

  ExerciseDefinition? byId(String id) {
    final rows = _db.select('SELECT * FROM exercises WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first, history(id));
  }

  /// Finished sessions of [exerciseId], newest first.
  ExerciseHistory history(String exerciseId) {
    final rows = _db.select(
      '''
      SELECT w.id, w.started_at, s.weight_kg, s.reps, s.rir, s.set_type,
             s.is_done
      FROM workouts w
      JOIN workout_exercises we ON we.workout_id = w.id
      JOIN workout_sets s
        ON s.workout_id = w.id AND s.exercise_position = we.position
      WHERE we.exercise_id = ? AND w.status = 'completed'
        AND w.deleted_at IS NULL
      ORDER BY w.started_at DESC, s.exercise_position, s.position
      ''',
      [exerciseId],
    );
    final setsByWorkout = <String, List<WorkoutSet>>{};
    final startedAt = <String, DateTime>{};
    for (final row in rows) {
      final id = row['id'] as String;
      startedAt[id] = DateTime.fromMillisecondsSinceEpoch(row['started_at']);
      final weight = (row['weight_kg'] as num).toDouble();
      final reps = row['reps'] as int;
      (setsByWorkout[id] ??= []).add(
        WorkoutSet(
          weightKg: weight,
          reps: reps,
          previousWeightKg: weight,
          previousReps: reps,
          rir: row['rir'] as int?,
          type: SetType.values.byName(row['set_type']),
          isDone: row['is_done'] == 1,
        ),
      );
    }
    final windowStart = _db.now().subtract(oneRepMaxWindow);
    final entries = <ExerciseHistoryEntry>[];
    double? bestEstimate;
    for (final MapEntry(key: id, value: sets) in setsByWorkout.entries) {
      final best = heaviestSet(sets);
      if (best == null) continue;
      final date = startedAt[id]!;
      entries.add(
        ExerciseHistoryEntry(
          date: date,
          weightKg: best.weightKg,
          reps: best.reps,
          rir: best.rir,
        ),
      );
      if (date.isBefore(windowStart)) continue;
      for (final set in countedSets(sets)) {
        final estimate = estimateOneRepMax(set.weightKg, set.reps);
        if (estimate != null && estimate > (bestEstimate ?? 0)) {
          bestEstimate = estimate;
        }
      }
    }
    return ExerciseHistory(
      recent: entries,
      sessionCount: entries.length,
      estimatedOneRepMaxKg: bestEstimate,
    );
  }

  /// Working sets done per finished session of [exerciseId], oldest first.
  List<(DateTime, int)> sessionSetCounts(String exerciseId) => [
    for (final row in _db.select(
      '''
      SELECT w.started_at AS started, COUNT(*) AS sets
      FROM workouts w
      JOIN workout_exercises we ON we.workout_id = w.id
      JOIN workout_sets s
        ON s.workout_id = w.id AND s.exercise_position = we.position
      WHERE we.exercise_id = ? AND w.status = 'completed'
        AND w.deleted_at IS NULL AND s.is_done = 1 AND s.set_type != 'warmup'
      GROUP BY w.id ORDER BY w.started_at
      ''',
      [exerciseId],
    ))
      (DateTime.fromMillisecondsSinceEpoch(row['started']), row['sets'] as int),
  ];

  /// Creates or updates [exercise], bumping its revision on update.
  void save(
    ExerciseDefinition exercise, {
    ChangeSource source = ChangeSource.local,
    String? importBatchId,
  }) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      final exists = _db.select('SELECT 1 FROM exercises WHERE id = ?', [
        exercise.id,
      ]).isNotEmpty;
      final values = [
        exercise.name,
        jsonEncode(exercise.aliases),
        exercise.equipment.name,
        jsonEncode([for (final m in exercise.primaryMuscles) m.name]),
        jsonEncode([for (final m in exercise.secondaryMuscles) m.name]),
        exercise.pattern.name,
        exercise.trackingType.name,
        exercise.source.name,
        jsonEncode(exercise.cues),
        exercise.isFavorite ? 1 : 0,
        exercise.isInHomeGym ? 1 : 0,
      ];
      if (exists) {
        _db.execute(
          'UPDATE exercises SET name = ?, aliases = ?, equipment = ?, '
          'primary_muscles = ?, secondary_muscles = ?, pattern = ?, '
          'tracking_type = ?, ownership = ?, cues = ?, is_favorite = ?, '
          'is_in_home_gym = ?, updated_at = ?, revision = revision + 1 '
          'WHERE id = ?',
          [...values, now, exercise.id],
        );
      } else {
        _db.execute(
          'INSERT INTO exercises (name, aliases, equipment, primary_muscles, '
          'secondary_muscles, pattern, tracking_type, ownership, cues, '
          'is_favorite, is_in_home_gym, id, created_at, updated_at, source, '
          'import_batch_id) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [...values, exercise.id, now, now, source.name, importBatchId],
        );
      }
      _db.audit(
        entityType: 'exercise',
        entityId: exercise.id,
        action: exists ? 'update' : 'create',
        source: source,
        importBatchId: importBatchId,
      );
    });
  }

  void setFavorite(String id, {required bool isFavorite}) {
    _db.transaction(() {
      _db.execute(
        'UPDATE exercises SET is_favorite = ?, updated_at = ?, '
        'revision = revision + 1 WHERE id = ?',
        [isFavorite ? 1 : 0, _db.now().millisecondsSinceEpoch, id],
      );
      _db.audit(
        entityType: 'exercise',
        entityId: id,
        action: isFavorite ? 'favorite' : 'unfavorite',
      );
    });
  }

  /// The exercise an external app's name was mapped to earlier, if any.
  String? mappedId(String source, String externalName) {
    final rows = _db.select(
      'SELECT exercise_id FROM external_exercise_names '
      'WHERE source = ? AND name = ?',
      [source, externalName],
    );
    return rows.isEmpty ? null : rows.first['exercise_id'] as String;
  }

  /// Remembers that [externalName] in [source] means [exerciseId], so the
  /// next import maps it the same way.
  void mapExternalName(
    String source,
    String externalName,
    String exerciseId, {
    String? importBatchId,
  }) {
    _db.execute(
      'INSERT INTO external_exercise_names '
      '(source, name, exercise_id, import_batch_id) VALUES (?, ?, ?, ?) '
      'ON CONFLICT(source, name) DO UPDATE SET '
      'exercise_id = excluded.exercise_id, '
      'import_batch_id = excluded.import_batch_id',
      [source, externalName, exerciseId, importBatchId],
    );
  }

  ExerciseDefinition _fromRow(Row row, ExerciseHistory history) {
    final last = history.last;
    return ExerciseDefinition(
      id: row['id'],
      name: row['name'],
      aliases: _strings(row['aliases']),
      equipment: Equipment.values.byName(row['equipment']),
      primaryMuscles: [
        for (final name in _strings(row['primary_muscles']))
          MuscleGroup.values.byName(name),
      ],
      secondaryMuscles: [
        for (final name in _strings(row['secondary_muscles']))
          MuscleGroup.values.byName(name),
      ],
      pattern: MovementPattern.values.byName(row['pattern']),
      trackingType: TrackingType.values.byName(row['tracking_type']),
      source: ExerciseSource.values.byName(row['ownership']),
      cues: _strings(row['cues']),
      isFavorite: row['is_favorite'] == 1,
      isInHomeGym: row['is_in_home_gym'] == 1,
      recordCount: history.sessionCount,
      lastPerformance: last == null
          ? null
          : '上次 ${formatWeight(last.weightKg)} kg × ${last.reps}',
      lastUsedDaysAgo: last == null ? null : _daysBetween(last.date, _db.now()),
    );
  }

  static List<String> _strings(Object? json) =>
      (jsonDecode(json! as String) as List).cast<String>();
}

int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
