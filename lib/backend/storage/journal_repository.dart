import '../../domain/domain.dart';
import '../../shared/format.dart';
import 'database.dart';
import 'timeline_source.dart';

/// Body measurements and wellness check-ins.
class JournalRepository {
  JournalRepository(this._db);

  final AppDatabase _db;

  void addWeight(
    BodyWeight weight, {
    ChangeSource source = ChangeSource.local,
  }) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'INSERT INTO body_weights (id, measured_at, weight_kg, note, '
        'created_at, updated_at, source) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          weight.id,
          weight.measuredAt.millisecondsSinceEpoch,
          weight.weightKg,
          weight.note,
          now,
          now,
          source.name,
        ],
      );
      _db.audit(
        entityType: 'body_weight',
        entityId: weight.id,
        action: 'create',
        source: source,
      );
    });
  }

  void addWellness(
    WellnessEntry entry, {
    ChangeSource source = ChangeSource.local,
  }) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'INSERT INTO wellness_entries (id, recorded_at, kind, score, note, '
        'created_at, updated_at, source) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          entry.id,
          entry.recordedAt.millisecondsSinceEpoch,
          entry.kind.name,
          entry.score,
          entry.note,
          now,
          now,
          source.name,
        ],
      );
      _db.audit(
        entityType: 'wellness_entry',
        entityId: entry.id,
        action: 'create',
        source: source,
      );
    });
  }

  void addSleep(SleepEntry entry, {ChangeSource source = ChangeSource.local}) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'INSERT INTO sleep_entries (id, slept_at, duration_minutes, score, '
        'note, created_at, updated_at, source) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          entry.id,
          entry.sleptAt.millisecondsSinceEpoch,
          entry.duration.inMinutes,
          entry.score,
          entry.note,
          now,
          now,
          source.name,
        ],
      );
      _db.audit(
        entityType: 'sleep_entry',
        entityId: entry.id,
        action: 'create',
        source: source,
      );
    });
  }

  /// Nights logged in `[start, end)`, oldest first.
  List<SleepEntry> sleepBetween(DateTime start, DateTime end) => [
    for (final row in _db.select(
      'SELECT * FROM sleep_entries WHERE deleted_at IS NULL '
      'AND slept_at >= ? AND slept_at < ? ORDER BY slept_at',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    ))
      SleepEntry(
        id: row['id'],
        sleptAt: DateTime.fromMillisecondsSinceEpoch(row['slept_at']),
        duration: Duration(minutes: row['duration_minutes']),
        score: row['score'] as int?,
        note: row['note'],
      ),
  ];

  /// The oldest live row of [table], by its [timeColumn].
  DateTime? _earliest(String table, String timeColumn) {
    final first = _db
        .select(
          'SELECT MIN($timeColumn) AS first FROM $table '
          'WHERE deleted_at IS NULL',
        )
        .first['first'];
    return first == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(first as int);
  }

  /// Weights measured in `[start, end)`, oldest first.
  List<BodyWeight> weightsBetween(DateTime start, DateTime end) => [
    for (final row in _db.select(
      'SELECT * FROM body_weights WHERE deleted_at IS NULL '
      'AND measured_at >= ? AND measured_at < ? ORDER BY measured_at',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    ))
      BodyWeight(
        id: row['id'],
        measuredAt: DateTime.fromMillisecondsSinceEpoch(row['measured_at']),
        weightKg: (row['weight_kg'] as num).toDouble(),
        note: row['note'],
      ),
  ];

  /// Check-ins recorded in `[start, end)`, oldest first.
  List<WellnessEntry> wellnessBetween(DateTime start, DateTime end) => [
    for (final row in _db.select(
      'SELECT * FROM wellness_entries WHERE deleted_at IS NULL '
      'AND recorded_at >= ? AND recorded_at < ? ORDER BY recorded_at',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    ))
      WellnessEntry(
        id: row['id'],
        recordedAt: DateTime.fromMillisecondsSinceEpoch(row['recorded_at']),
        kind: WellnessKind.values.byName(row['kind']),
        score: row['score'],
        note: row['note'],
      ),
  ];
}

/// Body weights as log rows.
class BodyWeightTimelineSource extends TimelineSource {
  BodyWeightTimelineSource(this._journal);

  final JournalRepository _journal;

  @override
  RecordCategory get category => RecordCategory.body;

  @override
  DateTime? earliest() => _journal._earliest('body_weights', 'measured_at');

  @override
  List<(DateTime, TimelineEntry)> entriesIn(DateTime start, DateTime end) => [
    for (final weight in _journal.weightsBetween(start, end))
      (
        weight.measuredAt,
        TimelineEntry(
          timeLabel: formatTimeOfDay(weight.measuredAt),
          at: weight.measuredAt,
          recordId: weight.id,
          category: RecordCategory.body,
          title: '體重 ${_label(weight)}',
          detail: weight.note,
        ),
      ),
  ];

  @override
  Map<int, String> summariesIn(DateTime start, DateTime end) => {
    for (final weight in _journal.weightsBetween(start, end))
      weight.measuredAt.day: _label(weight),
  };

  static String _label(BodyWeight weight) =>
      '${formatWeight(weight.weightKg)} kg';
}

/// Nights of sleep as log rows.
class SleepTimelineSource extends TimelineSource {
  SleepTimelineSource(this._journal);

  final JournalRepository _journal;

  @override
  RecordCategory get category => RecordCategory.wellness;

  @override
  DateTime? earliest() => _journal._earliest('sleep_entries', 'slept_at');

  @override
  List<(DateTime, TimelineEntry)> entriesIn(DateTime start, DateTime end) => [
    for (final night in _journal.sleepBetween(start, end))
      (
        night.sleptAt,
        TimelineEntry(
          timeLabel: formatTimeOfDay(night.sleptAt),
          at: night.sleptAt,
          recordId: night.id,
          category: RecordCategory.wellness,
          title: _label(night),
          detail: [
            if (night.score != null) '品質 ${night.score} / 5',
            if (night.note.isNotEmpty) '備註：${night.note}',
          ].join(' · '),
        ),
      ),
  ];

  @override
  Map<int, String> summariesIn(DateTime start, DateTime end) => {
    for (final night in _journal.sleepBetween(start, end))
      night.sleptAt.day: _label(night),
  };

  static String _label(SleepEntry night) =>
      '睡眠 ${formatHoursMinutes(night.duration)}';
}

/// Energy, mood and symptom check-ins as log rows.
class WellnessTimelineSource extends TimelineSource {
  WellnessTimelineSource(this._journal);

  final JournalRepository _journal;

  @override
  RecordCategory get category => RecordCategory.wellness;

  @override
  DateTime? earliest() => _journal._earliest('wellness_entries', 'recorded_at');

  @override
  List<(DateTime, TimelineEntry)> entriesIn(DateTime start, DateTime end) => [
    for (final entry in _journal.wellnessBetween(start, end))
      (
        entry.recordedAt,
        TimelineEntry(
          timeLabel: formatTimeOfDay(entry.recordedAt),
          at: entry.recordedAt,
          recordId: entry.id,
          category: RecordCategory.wellness,
          title: _label(entry),
          detail: entry.note.isEmpty ? '' : '備註：${entry.note}',
        ),
      ),
  ];

  @override
  Map<int, String> summariesIn(DateTime start, DateTime end) => {
    for (final entry in _journal.wellnessBetween(start, end))
      entry.recordedAt.day: _label(entry),
  };

  static String _label(WellnessEntry entry) =>
      '${entry.kind.label} ${entry.score} / 5';
}
