import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'schema.dart';

enum DatabaseOpenStage {
  inspection,
  opening,
  configuration,
  validation,
  migration,
  initialization,
  access,
}

enum DatabaseFailureKind {
  busy,
  locked,
  unavailable,
  access,
  corrupt,
  incompatibleVersion,
  missing,
  initialization,
}

/// Keeps the original error for diagnosis without putting its SQL, values or
/// paths in a user-facing message or an ordinary log line.
class DatabaseOpenFailure implements Exception {
  const DatabaseOpenFailure({
    required this.kind,
    required this.stage,
    required this.cause,
    required this.stackTrace,
    this.existingFile,
  });

  factory DatabaseOpenFailure.from(
    Object cause,
    StackTrace stackTrace, {
    required DatabaseOpenStage stage,
    bool? existingFile,
  }) {
    if (cause is DatabaseOpenFailure) return cause;
    final kind = switch (cause) {
      SchemaVersionMismatch() => DatabaseFailureKind.incompatibleVersion,
      ProtectedDataUnavailable() => DatabaseFailureKind.unavailable,
      MissingDatabase() => DatabaseFailureKind.missing,
      InvalidDatabase() => DatabaseFailureKind.corrupt,
      SqliteException(resultCode: 5) => DatabaseFailureKind.busy,
      SqliteException(resultCode: 6) => DatabaseFailureKind.locked,
      SqliteException(resultCode: 11 || 26) => DatabaseFailureKind.corrupt,
      SqliteException(resultCode: 3 || 8 || 10 || 13 || 14) =>
        DatabaseFailureKind.access,
      FileSystemException() => DatabaseFailureKind.access,
      _ => DatabaseFailureKind.initialization,
    };
    return DatabaseOpenFailure(
      kind: kind,
      stage: stage,
      cause: cause,
      stackTrace: stackTrace,
      existingFile: existingFile,
    );
  }

  final DatabaseFailureKind kind;
  final DatabaseOpenStage stage;
  final Object cause;
  final StackTrace stackTrace;
  final bool? existingFile;

  int? get resultCode => switch (cause) {
    SqliteException(:final resultCode) => resultCode,
    _ => null,
  };

  int? get extendedResultCode => switch (cause) {
    SqliteException(:final extendedResultCode) => extendedResultCode,
    _ => null,
  };

  @override
  String toString() =>
      'DatabaseOpenFailure(${kind.name}, ${stage.name}, $extendedResultCode)';
}

class MissingDatabase implements Exception {
  const MissingDatabase();
}

class InvalidDatabase implements Exception {
  const InvalidDatabase();
}

class ProtectedDataUnavailable implements Exception {
  const ProtectedDataUnavailable();
}
