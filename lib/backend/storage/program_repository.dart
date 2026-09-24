import '../../domain/domain.dart';
import 'database.dart';

/// Programs, their days, and what came of each day: the workouts that
/// trained one and the days skipped. Where a program stands is worked
/// out from these on each read (see `engines/program_progress.dart`).
class ProgramRepository {
  ProgramRepository(this._db);

  final AppDatabase _db;

  /// Every program, the running one first, then the newest.
  List<Program> all() => [
    for (final row in _db.select(
      'SELECT * FROM programs WHERE deleted_at IS NULL '
      'ORDER BY (started_at IS NOT NULL AND ended_at IS NULL) DESC, '
      'created_at DESC',
    ))
      _fromRow(row),
  ];

  Program? byId(String id) {
    final rows = _db.select(
      'SELECT * FROM programs WHERE id = ? AND deleted_at IS NULL',
      [id],
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  /// The program running now, if any; there is at most one.
  Program? running() {
    final rows = _db.select(
      'SELECT * FROM programs WHERE deleted_at IS NULL '
      'AND started_at IS NOT NULL AND ended_at IS NULL LIMIT 1',
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Program _fromRow(Map<String, Object?> row) {
    final id = row['id']! as String;
    DateTime? time(Object? ms) =>
        ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms as int);
    return Program(
      id: id,
      name: row['name']! as String,
      schedule: ProgramSchedule.values.byName(row['schedule']! as String),
      startedAt: time(row['started_at']),
      endedAt: time(row['ended_at']),
      days: [
        for (final day in _db.select(
          'SELECT routine_id, weekday FROM program_days '
          'WHERE program_id = ? ORDER BY position',
          [id],
        ))
          ProgramDay(
            routineId: day['routine_id']! as String,
            weekday: day['weekday'] as int?,
          ),
      ],
    );
  }

  /// Writes [program] and its days, new or edited.
  void save(Program program) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      final values = [
        program.name,
        program.schedule.name,
        program.startedAt?.millisecondsSinceEpoch,
        program.endedAt?.millisecondsSinceEpoch,
      ];
      final exists = _db.hasRow('programs', program.id);
      if (exists) {
        _db.execute(
          'UPDATE programs SET name = ?, schedule = ?, started_at = ?, '
          'ended_at = ?, updated_at = ?, revision = revision + 1 WHERE id = ?',
          [...values, now, program.id],
        );
        _db.execute('DELETE FROM program_days WHERE program_id = ?', [
          program.id,
        ]);
      } else {
        _db.execute(
          'INSERT INTO programs (name, schedule, started_at, ended_at, id, '
          'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [...values, program.id, now, now],
        );
      }
      for (final (position, day) in program.days.indexed) {
        _db.execute(
          'INSERT INTO program_days (program_id, position, routine_id, '
          'weekday) VALUES (?, ?, ?, ?)',
          [program.id, position, day.routineId, day.weekday],
        );
      }
      _db.audit(
        entityType: 'program',
        entityId: program.id,
        action: exists ? 'update' : 'create',
      );
    });
  }

  /// The routines some program holds, which are that program's own
  /// rather than the user's to train on their own.
  Set<String> routineIdsInPrograms() => {
    for (final row in _db.select(
      'SELECT d.routine_id FROM program_days d '
      'JOIN programs p ON p.id = d.program_id WHERE p.deleted_at IS NULL',
    ))
      row['routine_id']! as String,
  };

  /// Tombstones a program. Its workouts stay, as workouts, and its
  /// routines become the user's own again.
  void delete(String id) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'UPDATE programs SET deleted_at = ?, updated_at = ?, '
        'revision = revision + 1 WHERE id = ?',
        [now, now, id],
      );
      _db.audit(entityType: 'program', entityId: id, action: 'delete');
    });
  }

  /// Records that workout [workoutId] trains day [day] of [programId].
  void linkWorkout(String workoutId, String programId, int day) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'INSERT OR REPLACE INTO program_workouts (workout_id, program_id, '
        'day_position, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
        [workoutId, programId, day, now, now],
      );
      _db.audit(
        entityType: 'program_workout',
        entityId: workoutId,
        action: 'link',
        payload: {'program_id': programId, 'day': day},
      );
    });
  }

  /// Records that day [day] of [programId] was skipped.
  void skip(String programId, int day) {
    _db.transaction(() {
      final id = _db.newId();
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'INSERT INTO program_skips (id, program_id, day_position, '
        'skipped_at, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
        [id, programId, day, now, now, now],
      );
      _db.audit(
        entityType: 'program_skip',
        entityId: id,
        action: 'create',
        payload: {'program_id': programId, 'day': day},
      );
    });
  }

  /// [programId]'s days trained (finished workouts) and skipped, oldest
  /// first.
  List<ProgramDayRecord> records(String programId) {
    final records = [
      for (final row in _db.select(
        'SELECT pw.workout_id, pw.day_position, w.started_at '
        'FROM program_workouts pw JOIN workouts w ON w.id = pw.workout_id '
        "WHERE pw.program_id = ? AND w.status = 'completed' "
        'AND w.deleted_at IS NULL AND pw.deleted_at IS NULL',
        [programId],
      ))
        ProgramDayRecord(
          day: row['day_position']! as int,
          at: DateTime.fromMillisecondsSinceEpoch(row['started_at']! as int),
          workoutId: row['workout_id']! as String,
        ),
      for (final row in _db.select(
        'SELECT day_position, skipped_at FROM program_skips '
        'WHERE program_id = ? AND deleted_at IS NULL',
        [programId],
      ))
        ProgramDayRecord(
          day: row['day_position']! as int,
          at: DateTime.fromMillisecondsSinceEpoch(row['skipped_at']! as int),
        ),
    ];
    return records..sort((a, b) => a.at.compareTo(b.at));
  }
}
