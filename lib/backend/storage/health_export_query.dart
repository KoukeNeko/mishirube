import 'database.dart';

/// A record changed since the last write to a health platform: added,
/// edited or deleted. [detail] is what decides where it goes there: a
/// body reading's metric.
typedef HealthChange = ({
  String table,
  String id,
  int updatedAt,
  bool isDeleted,
  String? detail,
});

/// The records a health platform can hold, changed after [since] (ms),
/// oldest change first. What came from a health platform is never sent
/// back to one, and the demo content is not the user's.
///
/// Only a waist measurement and a mood have a place there among their
/// kinds; a workout or an activity only once it is finished.
List<HealthChange> healthChangesSince(AppDatabase db, int since) {
  const notOurs = "source NOT IN ('healthKit', 'healthConnect', 'seed')";
  const changed = 'updated_at > ? AND $notOurs';
  final rows = db.select('''
    SELECT 'body_weights' AS tbl, id, updated_at, deleted_at, NULL AS detail
      FROM body_weights WHERE $changed
    UNION ALL
    SELECT 'body_measurements', id, updated_at, deleted_at, NULL
      FROM body_measurements WHERE $changed AND site = 'waist'
    UNION ALL
    SELECT 'body_readings', id, updated_at, deleted_at, metric
      FROM body_readings WHERE $changed
    UNION ALL
    SELECT 'sleep_entries', id, updated_at, deleted_at, NULL
      FROM sleep_entries WHERE $changed
    UNION ALL
    SELECT 'meals', id, updated_at, deleted_at, NULL
      FROM meals WHERE $changed
    UNION ALL
    SELECT 'wellness_entries', id, updated_at, deleted_at, NULL
      FROM wellness_entries WHERE $changed AND kind = 'mood'
    UNION ALL
    SELECT 'workouts', id, updated_at, deleted_at, NULL
      FROM workouts WHERE $changed
        AND (status = 'finished' OR deleted_at IS NOT NULL)
    UNION ALL
    SELECT 'activities', id, updated_at, deleted_at, NULL
      FROM activities WHERE $changed
        AND (status = 'finished' OR deleted_at IS NOT NULL)
    ORDER BY updated_at
    ''', List.filled(8, since));
  return [
    for (final row in rows)
      (
        table: row['tbl']! as String,
        id: row['id']! as String,
        updatedAt: row['updated_at']! as int,
        isDeleted: row['deleted_at'] != null,
        detail: row['detail'] as String?,
      ),
  ];
}

/// When finished workout [id] started and ended, and its name; null
/// when it is not there or not finished.
({DateTime start, DateTime end, String name})? finishedWorkoutSpan(
  AppDatabase db,
  String id,
) {
  final rows = db.select(
    'SELECT started_at, finished_at, name FROM workouts '
    "WHERE id = ? AND deleted_at IS NULL AND status = 'finished' "
    'AND finished_at IS NOT NULL',
    [id],
  );
  if (rows.isEmpty) return null;
  final row = rows.single;
  return (
    start: DateTime.fromMillisecondsSinceEpoch(row['started_at']! as int),
    end: DateTime.fromMillisecondsSinceEpoch(row['finished_at']! as int),
    name: row['name']! as String,
  );
}
