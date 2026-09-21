import '../../domain/domain.dart';
import '../storage/database.dart';

/// Where the records in the store came from: what the user typed, what
/// was imported and when, what shipped with the app, and what is only
/// demo content.
class ProvenanceService {
  ProvenanceService(this._db);

  final AppDatabase _db;

  /// Every table that holds something the user did, with the category it
  /// is shown under.
  static const _recordTables = {
    'workouts': RecordCategory.training,
    'activities': RecordCategory.activity,
    'meals': RecordCategory.nutrition,
    'body_weights': RecordCategory.body,
    'body_measurements': RecordCategory.body,
    'sleep_entries': RecordCategory.wellness,
    'wellness_entries': RecordCategory.wellness,
    'notes': RecordCategory.wellness,
  };

  /// Live records per category written by [source].
  Map<RecordCategory, int> recordCounts(ChangeSource source) {
    final counts = <RecordCategory, int>{};
    for (final MapEntry(key: table, value: category) in _recordTables.entries) {
      final count =
          _db.select(
                'SELECT COUNT(*) AS n FROM $table '
                'WHERE deleted_at IS NULL AND source = ?',
                [source.name],
              ).single['n']
              as int;
      if (count > 0) counts[category] = (counts[category] ?? 0) + count;
    }
    return counts;
  }

  /// Every import, newest first, with how many records it still holds.
  List<ImportRecord> imports() => [
    for (final row in _db.select(
      'SELECT * FROM import_batches ORDER BY imported_at DESC',
    ))
      ImportRecord(
        source: row['source']! as String,
        fileName: row['file_name'] as String?,
        importedAt: DateTime.fromMillisecondsSinceEpoch(
          row['imported_at']! as int,
        ),
        isUndone: row['undone_at'] != null,
        records: _recordTables.keys.fold(
          0,
          (sum, table) =>
              sum +
              (_db.select(
                    'SELECT COUNT(*) AS n FROM $table '
                    'WHERE import_batch_id = ? AND deleted_at IS NULL',
                    [row['id']],
                  ).single['n']
                  as int),
        ),
      ),
  ];

  /// The brand data shipped with the app, one entry per brand.
  List<CatalogueRecord> catalogues() => [
    for (final row in _db.select(
      'SELECT brand, COUNT(*) AS items, '
      'SUM(parent_id IS NULL) AS products, MAX(checked_at) AS checked '
      'FROM foods '
      "WHERE source = 'catalogue' AND deleted_at IS NULL GROUP BY brand "
      'ORDER BY brand',
    ))
      CatalogueRecord(
        brand: row['brand']! as String,
        products: row['products']! as int,
        sizes: (row['items']! as int) - (row['products']! as int),
        checkedAt: switch (row['checked'] as int?) {
          final at? => DateTime.fromMillisecondsSinceEpoch(at),
          null => null,
        },
      ),
  ];
}

/// One import as the user would recognise it.
class ImportRecord {
  const ImportRecord({
    required this.source,
    required this.fileName,
    required this.importedAt,
    required this.isUndone,
    required this.records,
  });

  final String source;
  final String? fileName;
  final DateTime importedAt;
  final bool isUndone;

  /// Records from this import that are still in the store.
  final int records;
}

/// A brand's data shipped with the app.
class CatalogueRecord {
  const CatalogueRecord({
    required this.brand,
    required this.products,
    required this.sizes,
    required this.checkedAt,
  });

  final String brand;
  final int products;

  /// Cup sizes across those products; each is its own read-only entry.
  final int sizes;

  /// When the figures were last checked against the brand's own pages.
  final DateTime? checkedAt;
}
