import '../../domain/domain.dart';
import 'database.dart';

/// The weekly goal's timeline and the stretches it was paused for.
/// Nothing about whether a week was met is stored here: that is derived
/// from the records every time it is read.
class GoalRepository {
  GoalRepository(this._db);

  final AppDatabase _db;

  List<WeeklyGoal> goals() => [
    for (final row in _db.select(
      'SELECT * FROM weekly_goals WHERE deleted_at IS NULL '
      'ORDER BY effective_from',
    ))
      WeeklyGoal(
        id: row['id']! as String,
        effectiveFrom: DateTime.fromMillisecondsSinceEpoch(
          row['effective_from']! as int,
        ),
        targetDays: row['target_days']! as int,
      ),
  ];

  /// Records that from [effectiveFrom] on, the goal is [targetDays].
  /// A goal already starting that day is rewritten rather than stacked,
  /// so changing one's mind twice in a week leaves one row.
  void setGoal(WeeklyGoal goal) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      final existing = _db.select(
        'SELECT id FROM weekly_goals WHERE effective_from = ? '
        'AND deleted_at IS NULL',
        [goal.effectiveFrom.millisecondsSinceEpoch],
      );
      if (existing.isNotEmpty) {
        _db.execute(
          'UPDATE weekly_goals SET target_days = ?, updated_at = ?, '
          'revision = revision + 1 WHERE id = ?',
          [goal.targetDays, now, existing.first['id']],
        );
      } else {
        _db.execute(
          'INSERT INTO weekly_goals (id, effective_from, target_days, '
          'created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
          [
            goal.id,
            goal.effectiveFrom.millisecondsSinceEpoch,
            goal.targetDays,
            now,
            now,
          ],
        );
      }
      _db.audit(
        entityType: 'weekly_goal',
        entityId: goal.id,
        action: 'set',
        payload: {'target_days': goal.targetDays},
      );
    });
  }

  List<GoalPause> pauses() => [
    for (final row in _db.select(
      'SELECT * FROM goal_pauses WHERE deleted_at IS NULL ORDER BY started_at',
    ))
      GoalPause(
        id: row['id']! as String,
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          row['started_at']! as int,
        ),
        endedAt: row['ended_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['ended_at']! as int),
        note: row['note']! as String,
      ),
  ];

  /// The pause still running, if any.
  GoalPause? openPause() {
    final open = pauses().where((pause) => pause.endedAt == null);
    return open.isEmpty ? null : open.last;
  }

  void startPause(GoalPause pause) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'INSERT INTO goal_pauses (id, started_at, ended_at, note, '
        'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
        [
          pause.id,
          pause.startedAt.millisecondsSinceEpoch,
          pause.endedAt?.millisecondsSinceEpoch,
          pause.note,
          now,
          now,
        ],
      );
      _db.audit(entityType: 'goal_pause', entityId: pause.id, action: 'start');
    });
  }

  void endPause(String id, DateTime endedAt) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'UPDATE goal_pauses SET ended_at = ?, updated_at = ?, '
        'revision = revision + 1 WHERE id = ?',
        [endedAt.millisecondsSinceEpoch, now, id],
      );
      _db.audit(entityType: 'goal_pause', entityId: id, action: 'end');
    });
  }
}
