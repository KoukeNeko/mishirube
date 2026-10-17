import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../shared/app_info.dart';
import 'database_open_failure.dart';
import 'schema.dart';

/// One bounded incident, outside SQLite so a failed open cannot erase the
/// reason. Only explicit, non-content fields are written, never error.toString.
class DatabaseDiagnostics {
  DatabaseDiagnostics(Directory directory)
    : file = File('${directory.path}/database-startup.json');

  final File file;

  static String _version = 'unknown';
  static String _build = 'unknown';

  static Future<void> readAppInfo() async {
    try {
      final info = await installedAppInfo();
      if (info != null) {
        _version = info.version;
        _build = info.build;
      }
    } on Exception catch (error) {
      _report(error);
    }
  }

  static Future<void> failedOnDevice(DatabaseOpenFailure failure) async {
    try {
      await readAppInfo();
      final directory = await getApplicationSupportDirectory();
      directory.createSync(recursive: true);
      DatabaseDiagnostics(directory).failed(failure, context: 'startup');
    } on Exception catch (error) {
      _report(error);
    }
  }

  void failed(DatabaseOpenFailure failure, {required String context}) {
    _write({
      'failedAt': DateTime.now().toUtc().toIso8601String(),
      'resolvedAt': null,
      'context': context,
      'appVersion': _version,
      'appBuild': _build,
      'schemaVersion': latestSchemaVersion,
      'platform': Platform.operatingSystem,
      'stage': failure.stage.name,
      'kind': failure.kind.name,
      'resultCode': failure.resultCode,
      'extendedResultCode': failure.extendedResultCode,
      'existingFile': failure.existingFile,
    });
  }

  void resolved({required String context}) {
    try {
      if (!file.existsSync()) return;
      final incident = jsonDecode(file.readAsStringSync());
      if (incident is! Map<String, dynamic>) {
        throw const FormatException('Invalid database diagnostic');
      }
      if (incident['context'] != context || incident['resolvedAt'] != null) {
        return;
      }
      _write({
        ...incident,
        'resolvedAt': DateTime.now().toUtc().toIso8601String(),
      });
    } on Exception catch (error) {
      _report(error);
    }
  }

  void _write(Map<String, Object?> incident) {
    final pending = File('${file.path}.$pid.${Isolate.current.hashCode}.tmp');
    try {
      // Atomic replacement keeps a failed write from replacing the previous
      // incident with half a JSON document.
      pending.writeAsStringSync(jsonEncode(incident), flush: true);
      pending.renameSync(file.path);
    } on Exception catch (error) {
      _report(error);
    } finally {
      try {
        if (pending.existsSync()) pending.deleteSync();
      } on Exception catch (error) {
        _report(error);
      }
    }
  }

  static void _report(Object error) => FlutterError.reportError(
    FlutterErrorDetails(
      exception: StateError(
        'Database diagnostic could not be saved '
        '(${error.runtimeType}).',
      ),
      library: 'database startup',
      silent: true,
    ),
  );
}
