import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/storage/schema.dart';

/// Pins every released migration step.
///
/// A database that already ran a step will never run it again, so
/// editing one only takes effect on fresh installs — and the two then
/// have different schemas that agree about their version number. The
/// only safe change is another step on the end.
void main() {
  test('released migration steps are never edited', () {
    final golden = File('test/golden/schema.txt');
    final current = [
      for (final (index, step) in schemaSteps.indexed)
        '$index ${sha256.convert(utf8.encode(step))}',
    ];

    if (!golden.existsSync()) {
      golden.writeAsStringSync('${current.join('\n')}\n');
      fail('Wrote the first schema golden; check it in and run again.');
    }

    final pinned = golden.readAsLinesSync().where((l) => l.isNotEmpty).toList();
    expect(
      current.length,
      greaterThanOrEqualTo(pinned.length),
      reason: 'a step was removed; a database that ran it cannot go back',
    );
    for (final (index, line) in pinned.indexed) {
      expect(
        current[index],
        line,
        reason:
            'migration step $index changed. A released step must not be '
            'edited — append a new one instead, so a database that already '
            'ran this step ends up with the same schema as a fresh install.',
      );
    }

    if (current.length > pinned.length) {
      golden.writeAsStringSync('${current.join('\n')}\n');
    }
  });
}
