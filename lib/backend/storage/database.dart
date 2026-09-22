import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import 'schema.dart';

/// Where a change came from, recorded on rows and in the audit log.
/// Where a change came from.
///
/// [catalogue] is the brand data shipped with the app. Those records
/// are read-only: the app replaces them wholesale when it updates, and
/// that is only safe because nobody has edited them in the meantime.
enum ChangeSource {
  local,
  seed,
  catalogue,
  aiDraft,
  strongImport,
  archiveImport,

  /// Read from Apple Health.
  healthKit,

  /// Read from Health Connect.
  healthConnect,
}

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
  ///
  /// A file that cannot be opened or read is not thrown back at the
  /// user: there is no server to restore from, so a corrupt file is set
  /// aside under `<path>.corrupt-<timestamp>` and a fresh one is opened
  /// in its place. [recoveredFrom] says whether that happened, so the
  /// app can tell the user where their old file went rather than
  /// pretending it started empty.
  factory AppDatabase.open(String path, {DateTime Function()? clock}) {
    final now = clock ?? DateTime.now;
    try {
      return AppDatabase._(_openFile(path), now);
    } on StateError {
      // A newer schema is a different problem: opening a fresh file
      // would throw away data this app simply cannot read yet.
      rethrow;
    } on SqliteException catch (_) {
      final moved = _setAside(path, now());
      final db = AppDatabase._(_openFile(path), now);
      db._recoveredFrom = moved;
      return db;
    }
  }

  static Database _openFile(String path) {
    final db = sqlite3.open(path);
    db.execute('PRAGMA journal_mode = WAL');
    // Reading the schema is what first touches the file's pages, so a
    // corrupt file fails here rather than at the first user action.
    db.select('SELECT count(*) FROM sqlite_schema');
    return db;
  }

  /// Renames the unreadable file (and its journal) out of the way.
  static String _setAside(String path, DateTime now) {
    final stamp = now.toIso8601String().replaceAll(':', '-');
    final target = '$path.corrupt-$stamp';
    for (final suffix in ['', '-wal', '-shm']) {
      final file = File('$path$suffix');
      if (file.existsSync()) file.renameSync('$target$suffix');
    }
    return target;
  }

  /// A throwaway database, for tests and previews.
  factory AppDatabase.inMemory({DateTime Function()? clock}) =>
      AppDatabase._(sqlite3.openInMemory(), clock ?? DateTime.now);

  final Database _db;
  final DateTime Function() _clock;
  final _random = Random.secure();

  /// Where the previous, unreadable file was moved to; null on a normal
  /// open.
  String? _recoveredFrom;

  String? get recoveredFrom => _recoveredFrom;

  DateTime now() => _clock();

  /// End bound for the range queries, whose end is exclusive, when the
  /// range should include what was recorded this very instant.
  DateTime get nowInclusive => now().add(const Duration(milliseconds: 1));

  int get schemaVersion => _db.userVersion;

  /// How much the store takes on disk, from SQLite's own page count, so
  /// it is the same number whether the file is on a phone or in memory.
  int get sizeInBytes {
    final row = _db
        .select(
          'SELECT page_count * page_size AS bytes '
          'FROM pragma_page_count(), pragma_page_size()',
        )
        .single;
    return row['bytes'] as int;
  }

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

  /// Whether [table] has a row with [id], live or tombstoned. An import
  /// asks this so a record the user deleted is not brought back.
  bool hasRow(String table, String id) =>
      _db.select('SELECT 1 FROM $table WHERE id = ?', [id]).isNotEmpty;

  /// Settings whose key starts with this are never exported.
  ///
  /// The settings table is written into the archive whole, so anything
  /// stored there travels in every backup. A key the user pastes in is
  /// not theirs to hand out with a file they might email themselves, so
  /// it goes under this prefix and the export skips it. The safe default
  /// is the one nobody has to remember.
  static const secretKeyPrefix = 'secret.';

  /// Whether [key] names something that must not leave the device.
  static bool isSecret(String key) => key.startsWith(secretKeyPrefix);

  /// SQL for a row's local day, falling back to the reader's own zone
  /// for rows recorded before the app kept one.
  ///
  /// [instantColumn] holds epoch milliseconds. The fallback is what the
  /// app did for every row until the column existed, so an old row keeps
  /// the day it has always been shown on.
  static String localDaySql(String instantColumn) =>
      'COALESCE(local_day, CAST(strftime('
      "'%Y%m%d', $instantColumn / 1000, 'unixepoch', 'localtime'"
      ') AS INTEGER))';

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
      // The key's name is audited, never its value — an audit trail that
      // quotes the secret is the same leak wearing a different hat.
      audit(entityType: 'setting', entityId: key, action: 'set');
    });
  }

  void close() => _db.close();
}
