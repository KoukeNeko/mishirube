import '../../domain/domain.dart';
import '../../shared/format.dart';
import 'database.dart';
import 'timeline_source.dart';

/// General exercise sessions: running, walking, a game of badminton.
/// Strength workouts stay in their own tables; the two never mix.
class ActivityRepository {
  ActivityRepository(this._db);

  final AppDatabase _db;

  void add(
    ActivitySession activity, {
    ChangeSource source = ChangeSource.local,
    String? importBatchId,
  }) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'INSERT INTO activities (id, type, native_type, started_at, '
        'ended_at, elapsed_ms, distance_m, elevation_gain_m, effort, note, '
        'created_at, updated_at, source, import_batch_id) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          activity.id,
          activity.type.id,
          activity.nativeType,
          activity.startedAt.millisecondsSinceEpoch,
          activity.endedAt.millisecondsSinceEpoch,
          activity.duration.inMilliseconds,
          activity.distanceMeters,
          activity.elevationGainMeters,
          activity.effort,
          activity.note,
          now,
          now,
          source.name,
          importBatchId,
        ],
      );
      _db.audit(
        entityType: 'activity',
        entityId: activity.id,
        action: 'create',
        source: source,
        importBatchId: importBatchId,
      );
    });
  }

  /// Rewrites a session in place. The id and its history stay; only what
  /// the user corrected changes.
  void update(
    ActivitySession activity, {
    ChangeSource source = ChangeSource.local,
  }) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'UPDATE activities SET type = ?, started_at = ?, ended_at = ?, '
        'elapsed_ms = ?, distance_m = ?, elevation_gain_m = ?, effort = ?, '
        'note = ?, updated_at = ?, revision = revision + 1 WHERE id = ?',
        [
          activity.type.id,
          activity.startedAt.millisecondsSinceEpoch,
          activity.endedAt.millisecondsSinceEpoch,
          activity.duration.inMilliseconds,
          activity.distanceMeters,
          activity.elevationGainMeters,
          activity.effort,
          activity.note,
          now,
          activity.id,
        ],
      );
      _db.audit(
        entityType: 'activity',
        entityId: activity.id,
        action: 'update',
        source: source,
      );
    });
  }

  /// Tombstones a session, so removing it can be taken back and the audit
  /// trail still shows it happened.
  void remove(String id) => _setDeleted(id, _db.now(), 'delete');

  /// Puts a removed session back, for the undo on the toast.
  void restore(String id) => _setDeleted(id, null, 'restore');

  void _setDeleted(String id, DateTime? deletedAt, String action) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'UPDATE activities SET deleted_at = ?, updated_at = ?, '
        'revision = revision + 1 WHERE id = ?',
        [deletedAt?.millisecondsSinceEpoch, now, id],
      );
      _db.audit(entityType: 'activity', entityId: id, action: action);
    });
  }

  ActivitySession? byId(String id) {
    final rows = _db.select(
      'SELECT * FROM activities WHERE id = ? AND deleted_at IS NULL',
      [id],
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// Sessions started in `[start, end)`, oldest first.
  List<ActivitySession> between(DateTime start, DateTime end) => [
    for (final row in _db.select(
      'SELECT * FROM activities WHERE deleted_at IS NULL '
      'AND started_at >= ? AND started_at < ? ORDER BY started_at',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    ))
      _fromRow(row),
  ];

  /// The types used most recently, newest first, for offering them again.
  List<ActivityType> recentTypes({int limit = 3}) => [
    for (final row in _db.select(
      'SELECT type, MAX(started_at) AS last FROM activities '
      'WHERE deleted_at IS NULL GROUP BY type ORDER BY last DESC LIMIT ?',
      [limit],
    ))
      ActivityTypes.byId(row['type']),
  ];

  /// How long the last session of [type] lasted, to start the form from.
  Duration? lastDurationOf(ActivityType type) {
    final rows = _db.select(
      'SELECT elapsed_ms FROM activities WHERE type = ? '
      'AND deleted_at IS NULL ORDER BY started_at DESC LIMIT 1',
      [type.id],
    );
    return rows.isEmpty
        ? null
        : Duration(milliseconds: rows.first['elapsed_ms']);
  }

  DateTime? earliest() {
    final first = _db
        .select(
          'SELECT MIN(started_at) AS first FROM activities '
          'WHERE deleted_at IS NULL',
        )
        .first['first'];
    return first == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(first as int);
  }

  ActivitySession _fromRow(Map<String, Object?> row) => ActivitySession(
    id: row['id']! as String,
    type: ActivityTypes.byId(row['type']! as String),
    nativeType: row['native_type'] as String?,
    startedAt: DateTime.fromMillisecondsSinceEpoch(row['started_at']! as int),
    duration: Duration(milliseconds: row['elapsed_ms']! as int),
    distanceMeters: (row['distance_m'] as num?)?.toDouble(),
    elevationGainMeters: (row['elevation_gain_m'] as num?)?.toDouble(),
    effort: row['effort'] as int?,
    note: row['note']! as String,
  );
}

/// Exercise sessions as log rows.
class ActivityTimelineSource extends TimelineSource {
  ActivityTimelineSource(this._activities);

  final ActivityRepository _activities;

  @override
  RecordCategory get category => RecordCategory.activity;

  @override
  DateTime? earliest() => _activities.earliest();

  @override
  List<(DateTime, TimelineEntry)> entriesIn(DateTime start, DateTime end) => [
    for (final activity in _activities.between(start, end))
      (
        activity.startedAt,
        TimelineEntry(
          timeLabel: formatTimeOfDay(activity.startedAt),
          at: activity.startedAt,
          recordId: activity.id,
          category: RecordCategory.activity,
          title: activity.type.label,
          detail: activity.description,
          tags: [
            if (activity.effort case final effort?) '強度 $effort / 10',
            if (activity.note.isNotEmpty) activity.note,
          ],
        ),
      ),
  ];

  @override
  Map<int, String> summariesIn(DateTime start, DateTime end) {
    final byDay = <int, List<ActivitySession>>{};
    for (final activity in _activities.between(start, end)) {
      (byDay[activity.startedAt.day] ??= []).add(activity);
    }
    return {
      for (final MapEntry(key: day, value: activities) in byDay.entries)
        day: activities.length == 1
            ? '${activities.single.type.label} · '
                  '${activities.single.duration.inMinutes} 分'
            : '${activities.length} 場 · '
                  '${activities.fold(Duration.zero, (sum, a) => sum + a.duration).inMinutes} 分',
    };
  }
}
