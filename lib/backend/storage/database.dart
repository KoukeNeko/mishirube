import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

import 'database_diagnostics.dart';
import 'database_open_failure.dart';
import 'schema.dart';

export 'database_open_failure.dart';

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
  AppDatabase._(this._db, this._clock, this.path);

  /// Opens (creating or upgrading) the database file at [path].
  ///
  /// An opening failure never moves, replaces or recreates an existing
  /// database. Only a clean first install may create a new file.
  factory AppDatabase.open(String path, {DateTime Function()? clock}) =>
      AppDatabase._(_openFile(path, create: true), clock ?? DateTime.now, path);

  /// A second connection to the file at [path], which a store opened with
  /// [AppDatabase.open] is already using: for writing on another isolate
  /// while the screens keep theirs. It never creates or migrates a file;
  /// the main connection must have completed initialization first.
  factory AppDatabase.connect(String path, {DateTime Function()? clock}) =>
      AppDatabase._(
        _openFile(path, create: false),
        clock ?? DateTime.now,
        path,
      );

  static Database _openFile(String path, {required bool create}) {
    Database? db;
    bool? existing;
    var stage = DatabaseOpenStage.inspection;
    final file = File(path);
    final diagnostics = DatabaseDiagnostics(file.parent);
    final context = create ? 'startup' : 'background';
    try {
      existing = file.existsSync();
      if (!existing) {
        final name = file.uri.pathSegments.last;
        final remnants =
            file.parent.existsSync() &&
            file.parent.listSync().any((item) {
              final sibling = item.uri.pathSegments.last;
              return sibling == '$name-wal' ||
                  sibling == '$name-shm' ||
                  sibling.startsWith('$name.corrupt-');
            });
        if (!create || remnants) throw const MissingDatabase();
      }
      stage = DatabaseOpenStage.opening;
      db = sqlite3.open(
        path,
        mode: existing ? OpenMode.readWrite : OpenMode.readWriteCreate,
      );
      stage = DatabaseOpenStage.configuration;
      _configure(db);
      stage = DatabaseOpenStage.validation;
      checkSchemaVersion(db, requireLatest: !create);
      if (existing) {
        // SQLite accepts an empty file as a new database. That does not
        // make it a valid existing app store, even at user_version 0.
        final core = db.select(
          "SELECT name FROM sqlite_schema WHERE type='table' "
          "AND name IN ('settings', 'audit_events')",
        );
        if (core.length != 2 || db.userVersion == 0) {
          throw const InvalidDatabase();
        }
      }
      if (create) {
        stage = DatabaseOpenStage.configuration;
        db.execute('PRAGMA journal_mode = WAL');
        stage = DatabaseOpenStage.migration;
        migrate(db);
      }
      diagnostics.resolved(context: context);
      return db;
    } catch (error, stack) {
      try {
        db?.close();
      } catch (closeError) {
        // Closing is secondary: preserve the original opening failure.
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: StateError(
              'Failed database connection could not close '
              '(${closeError.runtimeType}).',
            ),
            library: 'database startup',
            silent: true,
          ),
        );
      }
      final failure = DatabaseOpenFailure.from(
        error,
        stack,
        stage: stage,
        existingFile: existing,
      );
      diagnostics.failed(failure, context: context);
      Error.throwWithStackTrace(failure, stack);
    }
  }

  static void _configure(Database db) => db
    ..execute('PRAGMA busy_timeout = 5000')
    ..execute('PRAGMA foreign_keys = ON');

  /// A throwaway database, for tests and previews.
  factory AppDatabase.inMemory({DateTime Function()? clock}) {
    final db = sqlite3.openInMemory();
    try {
      _configure(db);
      migrate(db);
      return AppDatabase._(db, clock ?? DateTime.now, null);
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  /// The file this store lives in; null for one in memory, which no other
  /// connection can reach.
  final String? path;

  final Database _db;
  final DateTime Function() _clock;
  final _random = Random.secure();
  final _changes = _Changes();

  /// Fires after every committed write, whoever made it: a view model
  /// listens here so a meal logged on one screen shows on the next
  /// without the two knowing about each other.
  Listenable get changes => _changes;

  /// Tells [changes] about a write another connection to the same file
  /// committed ([AppDatabase.connect]), which this one cannot see made.
  void notifyWrittenElsewhere() => _changes.notify();

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
      _changes.notify();
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

  void close() {
    _changes.dispose();
    _db.close();
  }
}

class _Changes extends ChangeNotifier {
  void notify() => notifyListeners();
}
