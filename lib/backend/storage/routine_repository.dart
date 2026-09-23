import '../../domain/domain.dart';
import 'database.dart';

/// Training templates (the plan side). Saving a routine never touches
/// finished workouts, which keep their own copy of what was done.
class RoutineRepository {
  RoutineRepository(this._db);

  final AppDatabase _db;

  /// [exercises] resolves the ids stored in the plan.
  Routine? byId(String id, Map<String, ExerciseDefinition> exercises) {
    final rows = _db.select(
      'SELECT * FROM routines WHERE id = ? AND deleted_at IS NULL',
      [id],
    );
    if (rows.isEmpty) return null;
    final routine = rows.first;
    final planned = _db.select(
      'SELECT * FROM routine_exercises WHERE routine_id = ? ORDER BY position',
      [id],
    );
    return Routine(
      id: id,
      name: routine['name'],
      programName: routine['program_name'],
      estimatedMinutes: routine['estimated_minutes'],
      lastCompletedLabel: _lastCompletedLabel(id),
      exercises: [
        for (final row in planned)
          PlannedExercise(
            exercise: exercises[row['exercise_id']]!,
            sets: row['sets'],
            reps: row['reps'],
            rir: row['rir'],
            targetWeightKg: (row['target_weight_kg'] as num).toDouble(),
            progressionLabel: row['progression_label'],
            isUnilateral: row['is_unilateral'] == 1,
          ),
      ],
    );
  }

  /// Every template, oldest first, so the list does not reshuffle itself
  /// as they are edited.
  List<Routine> all(Map<String, ExerciseDefinition> exercises) => [
    for (final row in _db.select(
      'SELECT id FROM routines WHERE deleted_at IS NULL ORDER BY created_at',
    ))
      byId(row['id']! as String, exercises)!,
  ];

  /// Tombstones a template. Finished workouts keep their own copy of what
  /// was done, so history is untouched and [restore] brings the plan back.
  void remove(String id) => _setDeleted(id, _db.now(), 'delete');

  void restore(String id) => _setDeleted(id, null, 'restore');

  void _setDeleted(String id, DateTime? deletedAt, String action) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'UPDATE routines SET deleted_at = ?, updated_at = ?, '
        'revision = revision + 1 WHERE id = ?',
        [deletedAt?.millisecondsSinceEpoch, now, id],
      );
      _db.audit(entityType: 'routine', entityId: id, action: action);
    });
  }

  String _lastCompletedLabel(String routineId) {
    final rows = _db.select(
      "SELECT MAX(started_at) AS last FROM workouts WHERE routine_id = ? "
      "AND status = 'completed' AND deleted_at IS NULL",
      [routineId],
    );
    final last = rows.first['last'] as int?;
    if (last == null) return '還沒完成過';
    final date = DateTime.fromMillisecondsSinceEpoch(last);
    return '上次 ${date.month} 月 ${date.day} 日完成';
  }

  /// Replaces the stored plan with [routine]. [action] names the change in
  /// the audit log (e.g. `add_exercises`, `accept_ai_proposal`).
  void save(
    Routine routine, {
    required String action,
    ChangeSource source = ChangeSource.local,
  }) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      final exists = _db.select('SELECT 1 FROM routines WHERE id = ?', [
        routine.id,
      ]).isNotEmpty;
      if (exists) {
        _db.execute(
          'UPDATE routines SET name = ?, program_name = ?, '
          'estimated_minutes = ?, updated_at = ?, revision = revision + 1 '
          'WHERE id = ?',
          [
            routine.name,
            routine.programName,
            routine.estimatedMinutes,
            now,
            routine.id,
          ],
        );
      } else {
        _db.execute(
          'INSERT INTO routines (id, name, program_name, estimated_minutes, '
          'created_at, updated_at, source) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [
            routine.id,
            routine.name,
            routine.programName,
            routine.estimatedMinutes,
            now,
            now,
            source.name,
          ],
        );
      }
      _db.execute('DELETE FROM routine_exercises WHERE routine_id = ?', [
        routine.id,
      ]);
      for (final (position, planned) in routine.exercises.indexed) {
        _db.execute(
          'INSERT INTO routine_exercises (routine_id, position, exercise_id, '
          'sets, reps, rir, target_weight_kg, progression_label, '
          'is_unilateral) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            routine.id,
            position,
            planned.exercise.id,
            planned.sets,
            planned.reps,
            planned.rir,
            planned.targetWeightKg,
            planned.progressionLabel,
            planned.isUnilateral ? 1 : 0,
          ],
        );
      }
      _db.audit(
        entityType: 'routine',
        entityId: routine.id,
        action: action,
        source: source,
        payload: [
          for (final planned in routine.exercises)
            {'exercise': planned.exercise.id, 'sets': planned.sets},
        ],
      );
    });
  }
}
