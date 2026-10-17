import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// A separate process lets the test kill SQLite without running close or
/// finalizers. All rows are synthetic, created by database_open_test.dart.
Future<void> main(List<String> arguments) async {
  final db = sqlite3.open(arguments.single, mode: OpenMode.readWrite);
  db.execute('PRAGMA wal_autocheckpoint = 0');
  db.execute('BEGIN IMMEDIATE');
  db.execute(
    "INSERT INTO settings VALUES ('wal_probe', 'committed before kill')",
  );
  db.execute('COMMIT');
  stdout.writeln('committed');
  await stdout.flush();
  // The parent owns this process and terminates it after observing COMMIT.
  await stdin.drain<void>();
  db.close();
}
