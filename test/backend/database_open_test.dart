import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/application/health_writer.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/backend/storage/database_diagnostics.dart';
import 'package:mishirube/backend/storage/schema.dart';
import 'package:sqlite3/sqlite3.dart';

void _lockThenRelease((String, SendPort) message) async {
  final db = sqlite3.open(message.$1);
  db.execute('PRAGMA locking_mode = EXCLUSIVE');
  db.execute('BEGIN EXCLUSIVE');
  db.execute('COMMIT');
  message.$2.send('locked');
  await Future<void>.delayed(const Duration(milliseconds: 350));
  db.close();
}

void main() {
  late Directory directory;
  late String path;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('mishirube_open_');
    path = '${directory.path}/store.sqlite3';
  });
  tearDown(() => directory.deleteSync(recursive: true));

  void createStore() {
    AppDatabase.open(path)
      ..setSetting('probe', 'original')
      ..close();
  }

  void expectNoReplacement() => expect(
    directory.listSync().where((f) => f.path.contains('.corrupt-')),
    isEmpty,
  );

  Matcher fails(DatabaseFailureKind kind) =>
      throwsA(isA<DatabaseOpenFailure>().having((e) => e.kind, 'kind', kind));

  List<FlutterErrorDetails> captureSecondaryErrors() {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);
    return errors;
  }

  test(
    'BUSY waits once, preserves the store, then reopens its original row',
    () {
      createStore();
      final before = File(path).readAsBytesSync();
      final locker = sqlite3.open(path);
      var locked = true;
      addTearDown(() {
        if (locked) locker.close();
      });
      locker.execute('PRAGMA locking_mode = EXCLUSIVE');
      locker.execute('BEGIN EXCLUSIVE');
      locker.execute('COMMIT');
      final watch = Stopwatch()..start();
      expect(
        () => AppDatabase.open(path),
        throwsA(
          isA<DatabaseOpenFailure>()
              .having((e) => e.resultCode, 'SQLite code', 5)
              .having((e) => e.cause, 'cause', isA<SqliteException>())
              .having((e) => e.existingFile, 'existing', true),
        ),
      );
      watch.stop();
      expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(4500));
      expect(watch.elapsedMilliseconds, lessThan(8000));
      expect(File(path).readAsBytesSync(), before);
      expectNoReplacement();
      locker.close();
      locked = false;
      final reopened = AppDatabase.open(path);
      addTearDown(reopened.close);
      expect(reopened.setting('probe'), 'original');
      final incident = jsonDecode(
        DatabaseDiagnostics(directory).file.readAsStringSync(),
      );
      expect(incident['kind'], 'busy');
      expect(incident['resolvedAt'], isNotNull);
    },
  );

  test(
    'a lock released on another isolate lets this attempt succeed',
    () async {
      createStore();
      final ready = ReceivePort();
      addTearDown(ready.close);
      final isolate = await Isolate.spawn(_lockThenRelease, (
        path,
        ready.sendPort,
      ));
      addTearDown(() => isolate.kill(priority: Isolate.immediate));
      expect(await ready.first.timeout(const Duration(seconds: 10)), 'locked');
      final db = AppDatabase.open(path);
      addTearDown(db.close);
      expect(db.setting('probe'), 'original');
      expectNoReplacement();
    },
  );

  test('committed WAL survives a process killed before checkpoint', () async {
    createStore();
    final packages = File('.dart_tool/package_config.json').absolute;
    final config = jsonDecode(packages.readAsStringSync());
    final flutter = (config['packages'] as List).singleWhere(
      (package) => package['name'] == 'flutter',
    );
    final flutterRoot = Directory.fromUri(
      packages.uri.resolve(flutter['rootUri'] as String),
    ).parent.parent;
    final dart = '${flutterRoot.path}/bin/cache/dart-sdk/bin/dart';
    final worker = await Process.start(dart, [
      'run',
      '--verbosity=error',
      'test/support/sqlite_process.dart',
      path,
    ]);
    addTearDown(() => worker.kill(ProcessSignal.sigkill));
    final errors = worker.stderr.transform(utf8.decoder).join();
    final lines = StreamIterator(
      worker.stdout.transform(utf8.decoder).transform(const LineSplitter()),
    );
    addTearDown(lines.cancel);
    expect(await lines.moveNext().timeout(const Duration(seconds: 45)), isTrue);
    expect(lines.current, 'committed');
    expect(File('$path-wal').lengthSync(), greaterThan(32));
    final oldReader = sqlite3.open(path, mode: OpenMode.readOnly);
    expect(
      oldReader
          .select("SELECT value FROM settings WHERE key='wal_probe'")
          .single['value'],
      'committed before kill',
    );
    oldReader.close();
    worker.kill(ProcessSignal.sigkill);
    await worker.exitCode;
    expect(await errors, isEmpty);
    final db = AppDatabase.open(path);
    addTearDown(db.close);
    expect(db.setting('wal_probe'), 'committed before kill');
    expect(db.setting('probe'), 'original');
    expect(db.select('PRAGMA integrity_check').single.values.single, 'ok');
    expectNoReplacement();
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('only a clean first install may create a file', () {
    expect(() => AppDatabase.connect(path), fails(DatabaseFailureKind.missing));
    expect(File(path).existsSync(), isFalse);
    for (final suffix in ['-wal', '-shm', '.corrupt-previous']) {
      final remnant = File('$path$suffix')..writeAsStringSync('kept');
      expect(() => AppDatabase.open(path), fails(DatabaseFailureKind.missing));
      expect(File(path).existsSync(), isFalse);
      expect(remnant.readAsStringSync(), 'kept');
      remnant.deleteSync();
    }
    final db = AppDatabase.open(path);
    addTearDown(db.close);
    expect(db.schemaVersion, latestSchemaVersion);
    expect(db.select('SELECT * FROM audit_events'), isEmpty);
  });

  test(
    'background isolate propagates a missing-store failure without creating it',
    () async {
      final future = writeHealthBatchApart(
        path,
        DateTime(2026),
        const HealthBatch(
          kinds: {},
          idPrefix: 'synthetic',
          changeSource: ChangeSource.healthKit,
          sleeps: [],
          sleepRange: null,
          readings: null,
          weights: [],
          waists: [],
          body: [],
          workouts: [],
          water: [],
          foods: [],
          moods: [],
          activity: [],
        ),
      );
      await expectLater(future, fails(DatabaseFailureKind.missing));
      expect(File(path).existsSync(), isFalse);
      expectNoReplacement();
    },
  );

  test(
    'an existing empty file or another SQLite schema is not initialized',
    () {
      File(path).writeAsBytesSync([]);
      expect(() => AppDatabase.open(path), fails(DatabaseFailureKind.corrupt));
      expect(File(path).lengthSync(), 0);
      final other = sqlite3.open(path);
      other.execute('CREATE TABLE other (value TEXT)');
      other.close();
      expect(() => AppDatabase.open(path), fails(DatabaseFailureKind.corrupt));
      final verify = sqlite3.open(path);
      addTearDown(verify.close);
      expect(
        verify
            .select("SELECT name FROM sqlite_schema WHERE type='table'")
            .map((r) => r['name']),
        ['other'],
      );
      expectNoReplacement();
    },
  );

  test('background connections neither migrate nor switch journal mode', () {
    final old = sqlite3.open(path)
      ..execute(schemaSteps.first)
      ..userVersion = 1;
    old.close();
    expect(
      () => AppDatabase.connect(path),
      fails(DatabaseFailureKind.incompatibleVersion),
    );
    final verifyOld = sqlite3.open(path);
    expect(verifyOld.userVersion, 1);
    expect(
      verifyOld.select('PRAGMA journal_mode').single.values.single,
      'delete',
    );
    verifyOld.close();
    final main = AppDatabase.open(path);
    main.close();
    final journal = sqlite3.open(path)..execute('PRAGMA journal_mode = DELETE');
    journal.close();
    final background = AppDatabase.connect(path);
    addTearDown(background.close);
    expect(
      background.select('PRAGMA journal_mode').single.values.single,
      'delete',
    );
  });

  test(
    'migration failure rolls back its earlier DDL and closes the connection',
    () {
      final fixture = sqlite3.open(path)
        ..execute(schemaSteps.first)
        ..userVersion = 1;
      fixture.execute("INSERT INTO settings VALUES ('probe', 'original')");
      // Step 2 adds body_weights.session_id before hitting this duplicate.
      fixture.execute('ALTER TABLE body_readings ADD COLUMN session_id TEXT');
      fixture.close();
      expect(
        () => AppDatabase.open(path),
        throwsA(
          isA<DatabaseOpenFailure>()
              .having((e) => e.stage, 'stage', DatabaseOpenStage.migration)
              .having((e) => e.cause, 'cause', isA<SqliteException>()),
        ),
      );
      final repair = sqlite3.open(path);
      expect(repair.userVersion, 1);
      expect(
        repair.select('PRAGMA table_info(body_weights)').map((r) => r['name']),
        isNot(contains('session_id')),
      );
      repair.execute('ALTER TABLE body_readings DROP COLUMN session_id');
      repair.close();
      final db = AppDatabase.open(path);
      addTearDown(db.close);
      expect(db.schemaVersion, latestSchemaVersion);
      expect(db.setting('probe'), 'original');
      expectNoReplacement();
    },
  );

  test('diagnostics retain codes but never SQL, personal values or paths', () {
    final cause = SqliteException(
      extendedResultCode: 262,
      message: 'private path ${directory.path}',
      causingStatement: 'SELECT private_meal FROM personal_records WHERE key=?',
      parametersToStatement: ['private credential value'],
    );
    final stack = StackTrace.current;
    final failure = DatabaseOpenFailure.from(
      cause,
      stack,
      stage: DatabaseOpenStage.validation,
      existingFile: true,
    );
    expect(failure.kind, DatabaseFailureKind.locked);
    expect(identical(failure.cause, cause), isTrue);
    expect(identical(failure.stackTrace, stack), isTrue);
    final diagnostics = DatabaseDiagnostics(directory);
    diagnostics.failed(failure, context: 'startup');
    final raw = diagnostics.file.readAsStringSync();
    for (final private in [
      directory.path,
      'private_meal',
      'personal_records',
      'private credential value',
    ]) {
      expect(raw, isNot(contains(private)));
      expect(failure.toString(), isNot(contains(private)));
    }
    final before = jsonDecode(raw);
    expect(before['resultCode'], 6);
    expect(before['extendedResultCode'], 262);
    expect(before['resolvedAt'], isNull);
    DatabaseDiagnostics(directory).resolved(context: 'background');
    expect(diagnostics.file.readAsStringSync(), raw);
    DatabaseDiagnostics(directory).resolved(context: 'startup');
    final after = jsonDecode(diagnostics.file.readAsStringSync());
    expect(after['failedAt'], before['failedAt']);
    expect(after['extendedResultCode'], 262);
    expect(after['resolvedAt'], isNotNull);
  });

  test('invalid diagnostic JSON cannot prevent opening a healthy store', () {
    final reported = captureSecondaryErrors();
    createStore();
    DatabaseDiagnostics(directory).file.writeAsStringSync('[]');
    final db = AppDatabase.open(path);
    addTearDown(db.close);
    expect(db.setting('probe'), 'original');
    expect(reported.single.exceptionAsString(), contains('FormatException'));
  });

  test(
    'a diagnostic write failure does not replace the original open error',
    () {
      final reported = captureSecondaryErrors();
      File(path).writeAsStringSync('original invalid bytes');
      Directory('${directory.path}/database-startup.json').createSync();
      expect(
        () => AppDatabase.open(path),
        throwsA(
          isA<DatabaseOpenFailure>().having(
            (e) => e.resultCode,
            'SQLite code',
            26,
          ),
        ),
      );
      expect(File(path).readAsStringSync(), 'original invalid bytes');
      expect(
        reported.single.exceptionAsString(),
        contains('FileSystemException'),
      );
      expect(
        reported.single.exceptionAsString(),
        isNot(contains(directory.path)),
      );
      expectNoReplacement();
    },
  );
}
