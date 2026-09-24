import '../../domain/domain.dart';
import 'database.dart';

/// What health platforms counted and measured about everyday movement
/// (see [ActivityMetric]). The platform is the source of truth: a sync
/// writes its current figure over the stored one, and nothing here is
/// typed in or edited.
class ActivitySampleRepository {
  ActivitySampleRepository(this._db);

  final AppDatabase _db;

  /// Stores each of [samples] under an id made from [idPrefix], the
  /// metric and the start, so reading a stretch again finds its bucket.
  /// A bucket whose value is unchanged is left alone; returns how many
  /// were added or changed.
  int sync(
    List<ActivitySample> samples, {
    required String idPrefix,
    required ChangeSource source,
  }) {
    if (samples.isEmpty) return 0;
    return _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      var changed = 0;
      for (final sample in samples) {
        final id =
            '$idPrefix-${sample.metric.name}-'
            '${sample.start.millisecondsSinceEpoch}';
        final existing = _db.select(
          'SELECT value, ended_at, deleted_at FROM activity_samples '
          'WHERE id = ?',
          [id],
        );
        if (existing.isEmpty) {
          _db.execute(
            'INSERT INTO activity_samples (id, metric, started_at, ended_at, '
            'value, created_at, updated_at, source) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            [
              id,
              sample.metric.name,
              sample.start.millisecondsSinceEpoch,
              sample.end.millisecondsSinceEpoch,
              sample.value,
              now,
              now,
              source.name,
            ],
          );
          changed++;
          continue;
        }
        final row = existing.first;
        if (row['value'] == sample.value &&
            row['ended_at'] == sample.end.millisecondsSinceEpoch &&
            row['deleted_at'] == null) {
          continue;
        }
        _db.execute(
          'UPDATE activity_samples SET value = ?, ended_at = ?, '
          'deleted_at = NULL, updated_at = ?, revision = revision + 1 '
          'WHERE id = ?',
          [sample.value, sample.end.millisecondsSinceEpoch, now, id],
        );
        changed++;
      }
      if (changed > 0) {
        _db.audit(
          entityType: 'activity_samples',
          entityId: idPrefix,
          action: 'sync',
          source: source,
          payload: {'changed': changed},
        );
      }
      return changed;
    });
  }

  /// [metric]'s samples starting in [from]–[to], oldest first.
  List<ActivitySample> between(
    ActivityMetric metric,
    DateTime from,
    DateTime to,
  ) => [
    for (final row in _db.select(
      'SELECT started_at, ended_at, value FROM activity_samples '
      'WHERE metric = ? AND started_at >= ? AND started_at < ? '
      'AND deleted_at IS NULL ORDER BY started_at',
      [metric.name, from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    ))
      ActivitySample(
        metric: metric,
        start: DateTime.fromMillisecondsSinceEpoch(row['started_at']! as int),
        end: DateTime.fromMillisecondsSinceEpoch(row['ended_at']! as int),
        value: (row['value']! as num).toDouble(),
      ),
  ];

  /// The metrics with any sample starting from [from] on.
  Set<ActivityMetric> recordedSince(DateTime from) {
    final byName = ActivityMetric.values.asNameMap();
    return {
      for (final row in _db.select(
        'SELECT DISTINCT metric FROM activity_samples '
        'WHERE started_at >= ? AND deleted_at IS NULL',
        [from.millisecondsSinceEpoch],
      ))
        ?byName[row['metric']],
    };
  }
}
