import 'dart:convert';

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

  /// The demo records hidden by [setShowsDemo], per table, as JSON; empty
  /// or absent while they show.
  static const _hiddenDemoKey = 'demo.hidden';

  /// Whether the demo records show alongside the user's own.
  bool get showsDemo => (_db.setting(_hiddenDemoKey) ?? '').isEmpty;

  /// Whether there is any demo content to show or hide.
  bool get hasDemo => !showsDemo || recordCounts(ChangeSource.seed).isNotEmpty;

  /// Hides every demo record still showing, or shows again exactly the
  /// ones it hid. Hiding is a tombstone like any delete, audited, so
  /// nothing is lost; a demo record the user deleted before stays
  /// deleted, since it is not among the hidden.
  void setShowsDemo(bool shows) {
    if (shows == showsDemo) return;
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      if (shows) {
        final hidden = jsonDecode(_db.setting(_hiddenDemoKey)!) as Map;
        for (final MapEntry(key: table, value: ids) in hidden.entries) {
          if (!_recordTables.containsKey(table)) continue;
          for (final id in (ids as List).cast<String>()) {
            _setDeleted(table as String, id, null, now, 'show_demo');
          }
        }
        _db.setSetting(_hiddenDemoKey, '');
        return;
      }
      final hidden = <String, List<String>>{};
      for (final table in _recordTables.keys) {
        final ids = [
          for (final row in _db.select(
            'SELECT id FROM $table WHERE deleted_at IS NULL AND source = ?',
            [ChangeSource.seed.name],
          ))
            row['id']! as String,
        ];
        for (final id in ids) {
          _setDeleted(table, id, now, now, 'hide_demo');
        }
        if (ids.isNotEmpty) hidden[table] = ids;
      }
      _db.setSetting(_hiddenDemoKey, jsonEncode(hidden));
    });
  }

  void _setDeleted(
    String table,
    String id,
    int? deletedAt,
    int now,
    String action,
  ) {
    _db.execute(
      'UPDATE $table SET deleted_at = ?, updated_at = ?, '
      'revision = revision + 1 WHERE id = ?',
      [deletedAt, now, id],
    );
    _db.audit(
      entityType: table,
      entityId: id,
      action: action,
      source: ChangeSource.seed,
    );
  }

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
      'SELECT brand, country, COUNT(*) AS items, '
      'SUM(parent_id IS NULL) AS products, MAX(checked_at) AS checked '
      'FROM foods '
      "WHERE source = 'catalogue' AND deleted_at IS NULL "
      'GROUP BY brand, country ORDER BY brand, country',
    ))
      CatalogueRecord(
        brand: row['brand']! as String,
        country: row['country']! as String,
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
    required this.country,
    required this.products,
    required this.sizes,
    required this.checkedAt,
  });

  final String brand;

  /// Where that data applies, as an ISO 3166-1 code: a chain's figures
  /// are one country's.
  final String country;

  /// `7-ELEVEN（台灣）`.
  String get label => labelOfBrand(brand, country);
  final int products;

  /// Cup sizes across those products; each is its own read-only entry.
  final int sizes;

  /// When the figures were last checked against the brand's own pages.
  final DateTime? checkedAt;
}
