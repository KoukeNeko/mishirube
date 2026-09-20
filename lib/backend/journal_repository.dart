import 'database.dart';

class BodyWeight {
  const BodyWeight({
    required this.id,
    required this.measuredAt,
    required this.weightKg,
    this.note = '',
  });

  final String id;
  final DateTime measuredAt;
  final double weightKg;
  final String note;
}

enum WellnessKind {
  energy('精力'),
  mood('心情'),
  sleep('睡眠');

  const WellnessKind(this.label);

  final String label;
}

/// A self-rated 1–5 check-in with an optional note.
class WellnessEntry {
  const WellnessEntry({
    required this.id,
    required this.recordedAt,
    required this.kind,
    required this.score,
    this.note = '',
  });

  final String id;
  final DateTime recordedAt;
  final WellnessKind kind;
  final int score;
  final String note;
}

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
