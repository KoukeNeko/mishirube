import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/import_export/canonical_archive.dart';
import 'package:mishirube/backend/import_export/csv_view.dart';
import 'package:mishirube/backend/storage/database.dart';

import 'support/harness.dart';

/// Nothing secret in the source, and nothing secret on the way out.
///
/// There is no server and no telemetry, so the only ways a credential
/// could escape this app are being written into the repository or
/// riding along in something the user exports. Both are checked here
/// rather than remembered.
/// Assembled at run time: a fixture that looks like a key must not be
/// a literal that looks like a key, or the scanner below would have to
/// be given an exception, and exceptions are how the real one gets in.
final _secret = ['sk', 'live', '0123456789abcdefghijklmnop'].join('-');

void main() {
  group('nothing secret in the source', () {
    test('no credential-shaped literal is committed', () {
      final offenders = <String>[];
      for (final file in _dartAndAssetFiles()) {
        final text = file.readAsStringSync();
        for (final pattern in _credentialPatterns) {
          for (final match in pattern.allMatches(text)) {
            offenders.add('${file.path}: ${match.group(0)}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'a key in the repository is a key in everybody\'s clone, '
            'and rotating it is the only fix',
      );
    });

    test('the app has no logging layer to leak through', () {
      final offenders = [
        for (final file in _dartFiles(Directory('lib')))
          if (RegExp(r'(^|\s)(print|debugPrint)\(')
              .hasMatch(file.readAsStringSync()))
            file.path,
      ];
      expect(
        offenders,
        isEmpty,
        reason:
            'anything printed lands in the device console, where the '
            'user cannot see it and did not agree to it. Redaction is '
            'easiest when there is nothing to redact.',
      );
    });
  });

  group('nothing secret on the way out', () {
    late Backend backend;

    setUp(() {
      backend = Backend.inMemory(clock: FakeClock().now);
      backend.db.setSetting('${AppDatabase.secretKeyPrefix}api_key', _secret);
      backend.db.setSetting('glass_millilitres', '350');
    });

    tearDown(() => backend.close());

    test('not in the archive', () {
      expect(
        encodeArchive(exportArchive(backend.db)),
        isNot(contains(_secret)),
      );
    });

    test('not in the CSV views', () {
      for (final MapEntry(key: name, value: csv) in exportCsvViews(
        backend.db,
      ).entries) {
        expect(csv, isNot(contains(_secret)), reason: name);
      }
    });

    test('not in the audit trail', () {
      final rows = backend.db.select(
        'SELECT entity_id, payload FROM audit_events '
        "WHERE entity_type = 'setting'",
      );
      expect(rows, hasLength(2), reason: 'both settings were recorded');
      for (final row in rows) {
        expect(
          [row['entity_id'], row['payload']].join(' '),
          isNot(contains(_secret)),
          reason:
              'the audit trail says a setting changed, by name. The '
              'value is what must not be repeated.',
        );
      }
    });
  });
}

/// Shapes of credential that are worth failing a build over: they are
/// distinctive enough not to fire on ordinary code.
final _credentialPatterns = [
  RegExp(r'sk-[A-Za-z0-9_-]{20,}'),
  RegExp(r'AIza[A-Za-z0-9_-]{30,}'),
  RegExp(r'gh[pousr]_[A-Za-z0-9]{30,}'),
  RegExp(r'xox[abprs]-[A-Za-z0-9-]{10,}'),
  RegExp('-----BEGIN [A-Z ]*PRIVATE KEY-----'),
];

Iterable<File> _dartAndAssetFiles() sync* {
  yield* _dartFiles(Directory('lib'));
  yield* _dartFiles(Directory('test'));
  final assets = Directory('assets');
  if (assets.existsSync()) {
    yield* assets
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'));
  }
}

Iterable<File> _dartFiles(Directory directory) => directory
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));
