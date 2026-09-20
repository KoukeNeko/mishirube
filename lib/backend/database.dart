import 'dart:convert';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import 'schema.dart';

/// Where a change came from, recorded on rows and in the audit log.
enum ChangeSource { local, seed, aiDraft, strongImport, archiveImport }

/// The on-device SQLite store: the app's source of truth.
///
/// Writes are synchronous and committed per user action, so a workout
/// survives the process being killed between two sets. Rows are never hard
/// deleted; `deleted_at` marks a tombstone and every change is written to
/// `audit_events` inside the same transaction as the change itself.
class AppDatabase {
  AppDatabase._(this._db, this._clock) {
    _db
      ..execute('PRAGMA foreign_keys = ON')
      ..execute('PRAGMA busy_timeout = 5000');
    migrate(_db);
  }

  /// Opens (creating or upgrading) the database file at [path].
  factory AppDatabase.open(String path, {DateTime Function()? clock}) {
    final db = sqlite3.open(path);
    db.execute('PRAGMA journal_mode = WAL');
    return AppDatabase._(db, clock ?? DateTime.now);
  }

  /// A throwaway database, for tests and previews.
  factory AppDatabase.inMemory({DateTime Function()? clock}) =>
      AppDatabase._(sqlite3.openInMemory(), clock ?? DateTime.now);

  final Database _db;
  final DateTime Function() _clock;
  final _random = Random.secure();

  DateTime now() => _clock();

  int get schemaVersion => _db.userVersion;

  /// A random, stable identifier for a new row.
  String newId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  ResultSet select(String sql, [List<Object?> parameters = const []]) =>
      _db.select(sql, parameters);

  void execute(String sql, [List<Object?> parameters = const []]) =>
      _db.execute(sql, parameters);

  /// Runs [action] atomically. Nested calls join the outer transaction.
  T transaction<T>(T Function() action) {
    if (!_db.autocommit) return action();
    _db.execute('BEGIN IMMEDIATE');
    try {
      final result = action();
      _db.execute('COMMIT');
      return result;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Records one change. Call it inside the transaction that made it.
  void audit({
    required String entityType,
    required String entityId,
    required String action,
    ChangeSource source = ChangeSource.local,
    String? importBatchId,
    Object? payload,
  }) {
    _db.execute(
      'INSERT INTO audit_events '
      '(occurred_at, entity_type, entity_id, action, source, import_batch_id, '
      'payload) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        now().millisecondsSinceEpoch,
        entityType,
        entityId,
        action,
        source.name,
        importBatchId,
        payload == null ? null : jsonEncode(payload),
      ],
    );
  }

  String? setting(String key) {
    final rows = _db.select('SELECT value FROM settings WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  void setSetting(String key, String value) {
    transaction(() {
      _db.execute(
        'INSERT INTO settings (key, value) VALUES (?, ?) '
        'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
        [key, value],
      );
      audit(entityType: 'setting', entityId: key, action: 'set');
    });
  }

  void close() => _db.close();
}
